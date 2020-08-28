##############################################
# $Id: myUtilsTemplate.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;
use JSON;
use Data::Dumper;

sub
LSFUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.
sub LSF_init() {

	## ReadLSF
	fhem('defmod ReadLSF at *03:15:00 {loadLSFfromWeb();;}');
	fhem("attr LoadLSFMeta room LSF");
	
	## LSF_Info_getReading
	fhem('defmod LSF_Info_getReading cmdalias get LSF_Info_.* .* AS {
		my $device = $EVTPART0;;
		my $reading =$EVTPART1;; 
		return ReadingsVal($device,$reading,"unknown Device or Reading");;
	}');
	fhem("attr LoadLSFMeta room LSF");
	
	## HMinfo für Heizplan
	fhem('defmod hm HMinfo');
	fhem('attr hm room HM,Sven');
	fhem('attr hm configTempFile plan.cfg');
	
	## LSF_LoadHeizPlan
	fhem('defmod LSF_LoadHeizPlan at *03:30:00 set hm tempListG restore');
	fhem("attr LSF_LoadHeizPlan room LSF");
}

sub LSF_createRoomDummy($) {
	my ( $room ) = @_;
	
	fhem("defmod LSF_Info_$room dummy");
	fhem("attr LSF_Info_$room room LSF,$room");
	fhem("attr LSF_Info_$room readingList isVorlesung isPause nachstePause");
	fhem("attr LSF_Info_$room setList isVorlesung isPause nachstePause");
	fhem("attr LSF_Info_$room stateFormat Vorlesung:isVorlesung <br>Pause:isPause <br>NächstePause:nachstePause");
}

sub LSF_deleteRoomDummy($) {
	my ( $room ) = @_;
	
	fhem("delete LSF_Info_$room");
}

sub generate_LoadLSFMeta(@) {
	my @roomArray = @_;
	
	my $roomArrayAsString = '"'. join('","', @roomArray) .'"';
	
	fhem('defmod LoadLSFMeta at +*00:01:00 {
		my @rooms = ('.$roomArrayAsString.');;
		readLSFdummies(\@rooms);;
	}');
	fhem("attr LoadLSFMeta room LSF");
}

sub loadLSFfromWeb() {
	print "\nLoad LSF-Data from Web\n";
	system('dotnet /opt/lsf/LSF\ Schnittstelle.dll');
}

sub readLSFdummies($) {
	#Gegeben
	#my @rooms = ('9.428', 'HS_C');
	my ($roomsRef) = @_;
	my @rooms = @$roomsRef;
	(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();

	#Gesucht
	my $isVorlesung;
	my $isPause = 0;
	my $nachstePause = '';

	#Demo
	#$wday =  3;
	#$hour =  9;
	#$min  = 25;

	#Wochentag umwandeln
	my $weekday = '';
	if ($wday == 0)         {$weekday = 'Sunday';}
	elsif ($wday == 1)    {$weekday = 'Monday';}
	elsif ($wday == 2)    {$weekday = 'Tuesday';}
	elsif ($wday == 3)    {$weekday = 'Wednesday';}
	elsif ($wday == 4)    {$weekday = 'Thursday';}
	elsif ($wday == 5)    {$weekday = 'Friday';}
	elsif ($wday == 6)    {$weekday = 'Saturday';}

	#Lese Datei
	my $filename = "metadata.json";
	my $json = "";
	if (open(my $fh, '<:encoding(UTF-8)', $filename)) {
		while (my $row = <$fh>) {
			$json .= $row;
		}
	} else {
		warn "LSF: coundn't read '$filename' $!";
	}

	#Decodieren
	my $meta = decode_json($json);

	foreach ( @rooms ) {
		#set room
		my $room = $_;

		#resert old
		$isVorlesung = 0;
		$isPause = 0;
		$nachstePause = '';

		#Pausen auslesen
		my $pausen = $$meta{'Rooms'}{$room}{'Pausen'}{$weekday}; # $$ -> dereferenzieren

		if (defined($pausen)) {
			my $arraygrosse = $#$pausen + 1; # $ -> dereferenzieren = array,  $# +1 -> array größe

			for (my $i = 0; $i < $arraygrosse; $i++) {
				#Variablen laden
				my $currentPause = @$pausen[$i];
				my $beginHour = $$currentPause{'Begin'}{'Hours'};
				my $beginMin = $$currentPause{'Begin'}{'Minutes'};
				my $endHour = $$currentPause{'End'}{'Hours'};
				my $endMin = $$currentPause{'End'}{'Minutes'};
				#print "Pause:\n" . Dumper($beginHour,$beginMin, $endHour, $endMin);

				#Check Pause:   Stunden weiter = true;  Stunden gleich => Minuten weiter?;  Stunden zukunft = false;
				if ($hour > $beginHour ? 1 : $hour == $beginHour ? $min >= $beginMin : 0) {
					#Pause hat Angefangen

					#Pause noch nicht vorbei?
					if ($hour <= $endHour && $min < $endMin) {
						$isPause = 1;
					}
				}
				else {
					#Nächste Pause
					$nachstePause = $beginHour . ':' . $beginMin;
					last; #break
				}
			}
		}

		#isVorlesung
		my $segmentgroesse = $$meta{'Segmentgroesse'};
		my $segmentIndex = int(($hour * 60 + $min) / $segmentgroesse); # int() schneidet tail ab
		my $belegung = $$meta{'Rooms'}{$room}{'Belegung'}{$weekday};

		if (@$belegung[$segmentIndex]) {
			$isVorlesung = 1;
		}
		else {
			$isVorlesung = 0;
		}

		#Debug Ausgabe
		#print "\n";
		#print $room."-Ausgabe\n";
		#print "=======\n";
		#print 'isVorlesung:  ' . Dumper($isVorlesung);
		#print 'isPause:      ' . Dumper($isPause);
		#print 'nachstePause: ' . Dumper($nachstePause);

		#Übergabe der Ergebnisse
		my $device = 'LSF_Info_' . $room;
		my $exists = InternalVal($device,'NAME',undef);
		if (defined($exists)) {
			fhem("setreading $device isVorlesung $isVorlesung");
			fhem("setreading $device nachstePause $nachstePause");
			
			## nur wenn Änderung
			my $old = ReadingsVal($device,'isPause',0);
			if ($old ne $isPause) {
				fhem("setreading $device isPause $isPause");
			}
		}
		else {
			print "\nPlease Define $device before load LSF-MetaData of Room: $room \n\n";
		}
	}
}

1;
