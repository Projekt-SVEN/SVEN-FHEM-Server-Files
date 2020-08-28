##############################################
# $Id: myUtilsTemplate.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;

use Time::Piece;


sub
SvenUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.
sub Sven_init() {
	## Fenster Manager
	fhem("defmod Sven_Manager dummy");
	fhem("attr Sven_Manager room Sven");
	fhem("attr Sven_Manager readingList lastHMID");
	fhem("attr Sven_Manager setList addRoom removeRoom");
	fhem("attr Sven_Manager stateFormat Initialisiert");
	
	## Steuerung
	fhem('defmod Sven_Manager_CMD cmdalias set Sven_Manager .* .* AS { Sven_Manager_Logic($EVTPART1, $EVTPART2);; }');
	fhem("attr Sven_Manager_CMD room Sven");
	
	## Gets
	fhem('defmod SVEN_gets cmdalias get Sven_((?!Log).)* .* AS {
			my $device = $EVTPART0;;my $reading =$EVTPART1;; 
			return ReadingsVal($device,$reading,"unknown Device or Reading");;
		}');
	fhem("attr SVEN_gets room Sven");
	
	## Date und Time
	fhem("defmod Date dummy");
	fhem("attr Date room Sven");
	fhem("defmod Date_Update at *00:00 { fhem 'set Date '.strftime('%d.%m.%y', localtime) }");
	fhem("attr Date_Update room Sven");
	
	fhem("defmod Time dummy");
	fhem("attr Time room Sven");
	fhem("defmod Time_Update at +*00:00:30 { fhem 'set Time '.strftime('%H:%M', localtime) }");
	fhem("attr Time_Update room Sven");
	
	## sollTempFensterZu Universal
	fhem('defmod Sven_sollTempFensterZu_Notify notify Sven_TemperaturManager_.*:sollTemp:.* {
		my $fensterManager = $NAME;;
		$fensterManager =~ s/TemperaturManager/FensterManager/ig;;
		my $fensterstatus = ReadingsVal($fensterManager,"status","geschlossen");;
		if ($fensterstatus eq "geschlossen") {
			fhem ("set $NAME sollTempFensterZu  $EVTPART1");;
		}
	}');
	fhem("attr Sven_sollTempFensterZu_Notify room Sven");
	
	## LSF
	LSF_init();
}

sub Sven_Manager_Logic($$) {
	my ($befehl, $value) = @_;

	if ($befehl eq 'addRoom') {
		Sven_createRoom($value);
		Sven_GroupAdd("Sven_Manager", 'rooms', $value);
		Sven_LSF_LoadRoom();
	}
	elsif ($befehl eq 'removeRoom') {
		Sven_deleteRoom($value);
		Sven_GroupRemove("Sven_Manager", 'rooms', $value);
		Sven_LSF_LoadRoom();
	}
}

sub Sven_LSF_LoadRoom() {
	my $roomsStr = ReadingsVal("Sven_Manager",'rooms','');
	
	my @rooms = split(':', $roomsStr);
	generate_LoadLSFMeta(@rooms);
}

sub Sven_createRoom($) {
	my ($room) = @_;
	
	mkdir("./log/".$room);
	
	## Tablet-UI	
	UIgeneration($room);
	
	## Fenster Manager
	fhem("defmod Sven_FensterManager_$room dummy");
	fhem("attr Sven_FensterManager_$room room $room");
	fhem("attr Sven_FensterManager_$room readingList status steuerung");
	fhem("attr Sven_FensterManager_$room setList status steuerung");
	fhem("attr Sven_FensterManager_$room webCmd steuerung offen:steuerung geschlossen");
	fhem("attr Sven_FensterManager_$room stateFormat Status: status");
	
	## TemperaturManager
	fhem("defmod Sven_TemperaturManager_$room dummy");
	fhem("attr Sven_TemperaturManager_$room room $room");
	fhem("attr Sven_TemperaturManager_$room readingList temp sollTemp sollTempFensterZu ventil");
	fhem("attr Sven_TemperaturManager_$room setList sollTemp ventil");
	fhem("attr Sven_TemperaturManager_$room stateFormat Temperatur: temp <br/>SollTemperatur: sollTemp <br/>Ventil: ventil");
	
	## HM Virtuell
	my $hmID = InternalVal("Sven_HMVirtuell_$room","DEF",undef);
	if (!defined($hmID)) {
		$hmID = Sven_getNextHMID();
	}
	fhem("defmod Sven_HMVirtuell_$room CUL_HM $hmID");
	fhem("attr Sven_HMVirtuell_$room room $room");
	fhem("attr Sven_HMVirtuell_$room modelForce VIRTUAL");
	
	## Zeitverzögert, sonst wirkt modelForce nicht
	fhem('defmod Sven_setDevice_'.$room.' at +00:00:05 {
		
		fhem("set Sven_HMVirtuell_'.$room.' virtual 2");;
		fhem("rename Sven_HMVirtuell_'.$room.'_Btn1 Sven_HMVirtuell_Fenster_'.$room.'");;
		fhem("rename Sven_HMVirtuell_'.$room.'_Btn2 Sven_HMVirtuell_Temp_'.$room.'");;
		fhem("attr Sven_HMVirtuell_Fenster_'.$room.' room '.$room.'");;
		fhem("attr Sven_HMVirtuell_Temp_'.$room.' room '.$room.'");;
	}');
	
	## EnergieManager
	fhem("defmod Sven_EnergieManager_$room dummy");
	fhem("attr Sven_EnergieManager_$room room $room");
	fhem("attr Sven_EnergieManager_$room readingList verbrauchProStunde letzte_berechnung " .
		"verbrauchTag verbrauchWoche verbrauchMonat " .
		"einsparungTag einsparungWoche einsparungMonat " .
		"ohneSevenTag ohneSevenWoche ohneSevenMonat");
	fhem("attr Sven_EnergieManager_$room setList verbrauchProStunde");
	fhem("attr Sven_EnergieManager_$room stateFormat ohne Sven: ohneSevenTag <br/>Verbrauch: verbrauchTag <br/>Einsparung: einsparungTag");
	
	## RaumManager
	fhem("defmod Sven_RaumManager_$room dummy");
	fhem("attr Sven_RaumManager_$room room $room");
	fhem("attr Sven_RaumManager_$room readingList fenster thermostate thermometer praesenzmelder fenstersteuerung inBenutzung inBenutzungReal");
	fhem("attr Sven_RaumManager_$room setList addFenster removeFenster " .
		"addThermostat removeThermostat " .
		"addThermometer removeThermometer " .
		"addPraesenzmelder removePraesenzmelder " .
		"addFenstersteuerung removeFenstersteuerung");
	fhem("attr Sven_RaumManager_$room webCmd inBenutzung leer:inBenutzung benutzt");
	fhem("attr Sven_RaumManager_$room stateFormat Benutzung: inBenutzung");
	
	## Notify RaumManager
	fhem("defmod Sven_CMD_RaumManager_$room cmdalias set Sven_RaumManager_$room .* .* AS " . 
		'{Sven_RoomManager_CMD("'.$room.'",$EVTPART1,$EVTPART2)}');
	fhem("attr Sven_CMD_RaumManager_$room room $room");
	
	## Berechne Energie
	fhem('defmod Sven_CalcEnergy_'.$room.' at +*00:01:00 {
			Sven_BerechneVerbrauch("'.$room.'");;
		}');
	fhem("attr Sven_CalcEnergy_$room room $room");
	
	## Reset Energie
	fhem('defmod Sven_ResetEnergy_'.$room.' at *00:00:00 {
			Sven_BerechneVerbrauch("'.$room.'");;
	 		Sven_EnergieReset("'.$room.'", "Tag");;
	 		if ($wday == 1) {
	 			Sven_EnergieReset("'.$room.'", "Woche");;
	 		}
			if ((strftime "%d",localtime time) eq "01") {
				Sven_EnergieReset("'.$room.'", "Monat");;
		 	}
		}');
	fhem("attr Sven_ResetEnergy_$room room $room");
	
	## Pausen Fenstersteuerung
	fhem('defmod Sven_WindowPauseNotify_'.$room.' notify LSF_Info_'.$room.':isPause:.* {
		if ($EVTPART1 > 0) {
			Sven_PauseFenstersteuerung("'.$room.'");;
		}
	}');
	fhem("attr Sven_WindowPauseNotify_$room room $room");
	
	## Log Dateien
	fhem("defmod Sven_EnergieLog_$room FileLog ./log/$room/EnergieLog-%Y-%U.log Sven_EnergieManager_$room:.*");
	fhem("attr Sven_EnergieLog_$room room $room");
	
	fhem("defmod Sven_FensterLog_$room FileLog ./log/$room/FensterLog-%Y-%U.log Sven_FensterManager_$room:.*");
	fhem("attr Sven_FensterLog_$room room $room");
	
	fhem("defmod Sven_RaumnutzungLog_$room FileLog ./log/$room/RaumnutzungLog-%Y-%U.log Sven_RaumManager_$room:.*");
	fhem("attr Sven_RaumnutzungLog_$room room $room");
	
	fhem("defmod Sven_TemperaturLog_$room FileLog ./log/$room/TemperaturLog-%Y-%U.log Sven_TemperaturManager_$room:.*");
	fhem("attr Sven_TemperaturLog_$room room $room");
	
	## LSF Dummy
	LSF_createRoomDummy($room);
}

sub Sven_deleteRoom($) {
	my ($room) = @_;
	
	fhem("delete Sven_.*_$room");
	LSF_deleteRoomDummy($room);
	deleteUIroom($room);
}

sub Sven_RoomManager_CMD($$$) {
	my ($room, $befehl, $value) = @_;
	
	## Verarbeite Befehl
	if ($befehl eq 'inBenutzung') {
		fhem("setreading Sven_RaumManager_$room inBenutzung $value");
	}
	elsif ($befehl eq 'addFenster') {
		Sven_GroupAdd("Sven_RaumManager_$room", 'fenster', $value);
		Sven_UpdateFenster($room);
	}
	elsif ($befehl eq 'removeFenster') {
		Sven_GroupRemove("Sven_RaumManager_$room", 'fenster', $value);
		Sven_UpdateFenster($room);
	}
	elsif ($befehl eq 'addThermostat') {
		Sven_GroupAdd("Sven_RaumManager_$room", 'thermostate', $value);
		Sven_UpdateThermostat($room);
		
		## Connect Virtuell Fenster
		fhem("set Sven_HMVirtuell_Fenster_$room peerChan 0 ".$value."_WindowRec single set");
		fhem("set ".$value."_WindowRec regSet winOpnTemp 5 Sven_HMVirtuell_Fenster_$room");
		fhem("set ".$value."_Clima regSet winOpnMode off"); ## Auto Fenstererkennung aus
		
		## Connect Virtuell Temp
		fhem("set Sven_HMVirtuell_Temp_$room peerChan 0 ".$value."_Weather single");
		
		## set Heizplan Entity
		fhem("attr ".$value."_Clima tempListTmpl $room");
		fhem("set hm tempListG restore");
	}
	elsif ($befehl eq 'removeThermostat') {
		Sven_GroupRemove("Sven_RaumManager_$room", 'thermostate', $value);
		Sven_UpdateThermostat($room);
	}
	elsif ($befehl eq 'addThermometer') {
		Sven_GroupAdd("Sven_RaumManager_$room", 'thermometer', $value);
		Sven_UpdateThermometer($room);
	}
	elsif ($befehl eq 'removeThermometer') {
		Sven_GroupRemove("Sven_RaumManager_$room", 'thermometer', $value);
		Sven_UpdateThermometer($room);
	}
	elsif ($befehl eq 'addPraesenzmelder') {
		Sven_GroupAdd("Sven_RaumManager_$room", 'praesenzmelder', $value);
		Sven_UpdatePraesenzmelder($room);
	}
	elsif ($befehl eq 'removePraesenzmelder') {
		Sven_GroupRemove("Sven_RaumManager_$room", 'praesenzmelder', $value);
		Sven_UpdatePraesenzmelder($room);
	}
	elsif ($befehl eq 'addFenstersteuerung') {
		Sven_GroupAdd("Sven_RaumManager_$room", 'fenstersteuerung', $value);
		Sven_UpdateFenstersteuerung($room);
	}
	elsif ($befehl eq 'removeFenstersteuerung') {
		Sven_GroupRemove("Sven_RaumManager_$room", 'fenstersteuerung', $value);
		Sven_UpdateFenstersteuerung($room);
	}
	else {
		print "\nUnbekannter Befehl:\nRaum: $room \nBefehl: $befehl \nValue: $value\n";
		return "\nUnbekannter Befehl:\nRaum: $room \nBefehl: $befehl \nValue: $value";
	}
}

sub Sven_UpdateFenster($) {
	my ($room) = @_;
	my $fensterstr = ReadingsVal("Sven_RaumManager_$room",'fenster','');
	
	## Wenn leer löschen
	if ($fensterstr eq '') {
		fhem("defmod Sven_NotifyFenster_$room notify unused {}");
		fhem("attr Sven_NotifyFenster_$room room $room");
		return;
	}
	
	## regex
	my $regex = $fensterstr;
	$regex =~ s/:/:.*|/ig;
	$regex .= ':.*';
	
	## Befehl
	my $fensterAsArray = $fensterstr;
	$fensterAsArray =~ s/:/","/ig;
	
	## redefine
	fhem('defmod Sven_NotifyFenster_'.$room.' notify '.$regex.' {
		Sven_BerechneVerbrauch("'.$room.'");;
		my $status = "geschlossen";;
		my @fensters = ("'.$fensterAsArray.'");;
		foreach ( @fensters ) {
			my $fenster = $_;;
			my $fensterStatus = ReadingsVal($fenster,"state","Open");;
			if ($fensterStatus eq "Open") {
				$status = "offen";;
			}
		}
		fhem("set Sven_FensterManager_'.$room.' status $status");;
		fhem("set Sven_HMVirtuell_Fenster_'.$room.' postEvent $status");;
	}');
	fhem("attr Sven_NotifyFenster_$room room $room");
}

sub Sven_UpdateFenstersteuerung($) {
	my ($room) = @_;
	my $steuerungen = ReadingsVal("Sven_RaumManager_$room",'fenstersteuerung','');
	
	## Wenn leer löschen
	if ($steuerungen eq '') {
		fhem("defmod Sven_NotifyFenstersteuerung_$room notify unused {}");
		fhem("attr Sven_NotifyFenstersteuerung_$room room $room");
		return;
	}
	
	## Befehl
	my $steuerungenAsArray = $steuerungen;
	$steuerungenAsArray =~ s/:/","/ig;
	
	## redefine
	fhem('defmod Sven_NotifyFenstersteuerung_'.$room.' notify Sven_FensterManager_'.$room.':steuerung:.* {
		my $status = "schliessen";;
		if ($EVTPART1 eq "offen") {
			$status = "oeffnen";;
		}
		
		## oeffen oder schiessen
		my @steuerungen = ("'.$steuerungenAsArray.'");;
		foreach ( @steuerungen ) {
			my $steuerung = $_;;
			fhem("set $steuerung $status");;
		}
	}');
	fhem("attr Sven_NotifyFenstersteuerung_$room room $room");
}

sub Sven_UpdateThermostat($) {
	my ($room) = @_;
	my $thermometerstr = ReadingsVal("Sven_RaumManager_$room",'thermostate','');
	
	## Wenn leer löschen
	if ($thermometerstr eq '') {
		fhem("defmod Sven_NotifyThermostat_$room notify unused {}");
		fhem("attr Sven_NotifyThermostat_$room room $room");
		fhem("defmod Sven_SetSollTemp_$room notify unused {}");
		fhem("attr Sven_SetSollTemp_$room room $room");
		return;
	}
	
	## regex
	my $regex = $thermometerstr;
	$regex =~ s/:/_Clima:.*|/ig;
	$regex .= '_Clima:.*';
	
	## Befehl
	my $thermometerAsArray = $thermometerstr;
	$thermometerAsArray =~ s/:/_Clima","/ig;
	$thermometerAsArray .= "_Clima";
	
	## redefine get Notify
	fhem('defmod Sven_NotifyThermostat_'.$room.' notify '.$regex.' {
		my @therms = ("'.$thermometerAsArray.'");;
		
		my $sum = 0;;
		my $sumTemp = 0;;
		my $count = 0;;
		foreach ( @therms ) {
			my $therm = $_;;
			$count++;;
			$sum += ReadingsVal($therm,"ValvePosition",0);;
			$sumTemp += ReadingsVal($therm,"desired-temp",0);;
		}
		
		my $erg = $sum / $count;;
		my $ergTemp = $sumTemp / $count;;
		fhem("set Sven_TemperaturManager_'.$room.' ventil $erg");;
		fhem("set Sven_TemperaturManager_'.$room.' sollTemp $ergTemp");;
	}');
	fhem("attr Sven_NotifyThermostat_$room room $room");
	
	## redefine get Notify
	fhem('defmod Sven_SetSollTemp_'.$room.' notify Sven_TemperaturManager_'.$room.':sollTemp:.* {
		my $value = $EVTPART1;;
		my @therms = ("'.$thermometerAsArray.'");;
		
		foreach ( @therms ) {
			my $therm = $_;;
			my $old = ReadingsNum($therm,"desired-temp", 0);;
			if ($value - $old ne 0) { # direktvergleich geht nicht da String mit int und double
				fhem("set $therm desired-temp $value");;
			}
		}
	}');
	fhem("attr Sven_SetSollTemp_$room room $room");
}

sub Sven_UpdateThermometer($) {
	my ($room) = @_;
	my $thermometerstr = ReadingsVal("Sven_RaumManager_$room",'thermometer','');
	
	## Wenn leer löschen
	if ($thermometerstr eq '') {
		fhem("defmod Sven_NotifyThermometer_$room notify unused {}");
		fhem("attr Sven_NotifyThermometer_$room room $room");
		return;
	}
	
	## regex
	my $regex = $thermometerstr;
	$regex =~ s/:/:.*|/ig;
	$regex .= ':.*';
	
	## Befehl
	my $thermometerAsArray = $thermometerstr;
	$thermometerAsArray =~ s/:/","/ig;
	
	## redefine
	fhem('defmod Sven_NotifyThermometer_'.$room.' notify '.$regex.' {
		my @therms = ("'.$thermometerAsArray.'");;
		my $sum = 0;;
		my $count = 0;;
		foreach ( @therms ) {
			my $therm = $_;;
			$count++;;
			$sum += ReadingsVal($therm,"temperature",0);;
		}
		
		my $erg = $sum / $count;;
		fhem("set Sven_TemperaturManager_'.$room.' temp $erg");;
		fhem("set Sven_HMVirtuell_Temp_'.$room.' virtTemp $erg");;
	}');
	fhem("attr Sven_NotifyThermometer_$room room $room");
}

sub Sven_UpdatePraesenzmelder($) {
	my ($room) = @_;
	my $preasensstr = ReadingsVal("Sven_RaumManager_$room",'praesenzmelder','');
	
	## Wenn leer löschen
	if ($preasensstr eq '') {
		fhem("defmod Sven_NotifyPraesenzmelder_$room notify unused {}");
		fhem("attr Sven_NotifyPraesenzmelder_$room room $room");
		return;
	}
	
	## regex
	my $regex = $preasensstr;
	$regex =~ s/:/:.*|/ig;
	$regex .= ':.*';
	
	## Befehl
	my $preasensAsArray = $preasensstr;
	$preasensAsArray =~ s/:/","/ig;
	
	## redefine
	fhem('defmod Sven_NotifyPraesenzmelder_'.$room.' notify '.$regex.' {
		my $oldStatus = ReadingsVal("Sven_RaumManager_'.$room.'","inBenutzungReal","leer");;
		my $status = "leer";;
		my @melderarr = ("'.$preasensAsArray.'");;
		foreach ( @melderarr ) {
			my $melder = $_;;
			my $melderStatus = ReadingsVal($melder,"state","leer");;
			if ($melderStatus eq "benutzt") {
				$status = "benutzt";;
			}
		}
		
		if ($status ne $oldStatus) {
			if ($status eq "benutzt") {
				fhem("setreading Sven_RaumManager_'.$room.' inBenutzungReal benutzt");;
				Sven_Praesenzmelder_Auftrag_Delete("'.$room.'");;
			}
			else {
				Sven_Praesenzmelder_Auftrag_Create("'.$room.'");;
			}
		}
	}');
	fhem("attr Sven_NotifyPraesenzmelder_$room room $room");
}

sub Sven_Praesenzmelder_Auftrag_Create($) {
	my ($room) = @_;
	my $auftrag = InternalVal("Sven_SetBenutztReal_$room", "NAME", undef);

	if (!defined($auftrag)) {
		fhem("defmod Sven_SetBenutztReal_$room at +00:00:20 {
			fhem('setreading Sven_RaumManager_$room inBenutzungReal leer');;
		}");
		fhem("attr Sven_SetBenutztReal_$room room $room");
	}
}

sub Sven_Praesenzmelder_Auftrag_Delete($) {
	my ($room) = @_;
	my $auftrag = InternalVal("Sven_SetBenutztReal_'.$room.'", "NAME", undef);
	
	if (defined($auftrag)) {
		fhem("delete Sven_SetBenutztReal_'.$room.'");;
	}
}

sub Sven_PauseFenstersteuerung($) {
	my ($room) = @_;
	my $steuerungen = ReadingsVal("Sven_RaumManager_$room",'fenstersteuerung','');
	
	## Wenn leer löschen
	if ($steuerungen eq '') {
		return;
	}
	
	## steuerung
	my $regen = ReadingsVal("Wetter","fc0_chOfRain00",0);;

	if ($regen < 80) {
		Sven_CreateFensterSchliessen($room);;
		
		## oeffen oder schiessen
		my @steuerungen = split(':', $steuerungen);
		foreach ( @steuerungen ) {
			my $steuerung = $_;;
			fhem("set $steuerung oeffnen");;
		}
	}
}

sub Sven_CreateFensterSchliessen($) {
	my ($room) = @_;
	my $steuerungen = ReadingsVal("Sven_RaumManager_$room",'fenstersteuerung','');
	
	if ($steuerungen eq '') {
		return;
	}
	
	## Befehl
	my $steuerungenAsArray = $steuerungen;
	$steuerungenAsArray =~ s/:/","/ig;
	
	## check Temp
	my $temp = ReadingsVal("Wetter",'temperature', 17);
	
	my $openTime = '00:15:00';
	if ($temp < 0 || $temp > 30) {
		$openTime = '00:05:00';
	}
	
	## redefine
	fhem('defmod Sven_CloseFenster_'.$room.' at +'.$openTime.' {
		my @steuerungen = ("'.$steuerungenAsArray.'");;
		foreach ( @steuerungen ) {
			my $steuerung = $_;;
			fhem("set $steuerung schliessen");;
		}
	}');
	fhem("attr Sven_CloseFenster_$room room $room");
}

sub Sven_EnergieReset($$) {
	my ($room, $interval) = @_;
	
	fhem ("set Sven_EnergieManager_$room   verbrauch$interval 0");
	fhem ("set Sven_EnergieManager_$room  ohneSeven$interval 0");
	fhem ("set Sven_EnergieManager_$room  einsparung$interval 0");
}

sub Sven_GroupAdd($$$) {
	my ($device, $reading, $value) = @_;
	my $str = ReadingsVal($device, $reading,'');
	
	## leer?
	if ($str eq '') {
		fhem("setreading $device $reading $value");
		return;
	}
	
	## breits vorhanden?
	my @devices = split(':', $str);
	foreach ( @devices ) {
		my $device = $_;
		if ($device eq $value) {
			## bereits vorhanden
			return;
		}
	}
	
	## add
	$str .= ':' . $value;
	fhem("setreading $device $reading $str");
}

sub Sven_GroupRemove($$$) {
	my ($device, $reading, $value) = @_;
	my $str = ReadingsVal($device, $reading,'');
	my $ret = '';
	
	my @devices = split(':', $str);
	foreach ( @devices ) {
		my $device = $_;
		
		## ist vorhanden?
		if ($device eq $value) {
			
			## überspringe
			next;
		}
		
		## bleibt erhalten
		if ($ret eq '') {
			$ret = $device;
		}
		else {
			$ret .= ':' . $device;
		}
	}

	if ($ret eq '') {
		fhem("deletereading $device $reading");
	}
	else {
		fhem("setreading $device $reading $ret");
	}
}

sub Sven_getNextHMID() {
	my $lastID_Hex = ReadingsVal("Sven_Manager","lastHMID","FF0000");
	my $lastID = hex($lastID_Hex);
	
	my $id = $lastID + 1;
	my $id_Hex = sprintf("%X", $id);
	fhem("setreading Sven_Manager lastHMID $id_Hex");
	
	if ($id > hex("FFFFFF")) {
		print "ERROR: Keine HMID mehr verfügbar!!!!!!!!!!!!!!!!!!!!!!!!!";
		return "FFFFFF";
	}
	
	return $id_Hex;
}

sub Sven_BerechneVerbrauch($) {
	my ($room) = @_;
	
	## rufe alte Werte ab
	my $Energie_ohneSven_30 	= ReadingsVal("Sven_EnergieManager_$room","ohneSevenMonat","0");
	my $Energie_ohneSven_7 		= ReadingsVal("Sven_EnergieManager_$room","ohneSevenWoche","0");
	my $Energie_ohneSven 		= ReadingsVal("Sven_EnergieManager_$room","ohneSevenTag","0");
	my $Energie_verbraucht_30 	= ReadingsVal("Sven_EnergieManager_$room","verbrauchMonat","0");
	my $Energie_verbraucht_7 	= ReadingsVal("Sven_EnergieManager_$room","verbrauchWoche","0");
	my $Energie_verbraucht 		= ReadingsVal("Sven_EnergieManager_$room","verbrauchTag","0");
	
	## Weitere Variablen
	my $now = time();
	my $last 				= ReadingsVal("Sven_EnergieManager_$room","letzte_berechnung", $now);
	
	my $ventil 					= ReadingsVal("Sven_TemperaturManager_$room","ventil",0);
	my $Verbrauch_pro_stunde 	= ReadingsVal("Sven_EnergieManager_$room","verbrauchProStunde","0");
	
	my $fensterstatus 			= ReadingsVal("Sven_FensterManager_$room","status","geschlossen");
	
	my $raumtemp 				= ReadingsVal("Sven_TemperaturManager_$room","temp",17);
	my $solltempFensterZu		= ReadingsVal("Sven_TemperaturManager_$room","sollTempFensterZu",20);
	
	
	## Set letzte_berechnung
	fhem ("set Sven_EnergieManager_$room letzte_berechnung $now");
	
	## Berechne Verbrauch seit letzter Berechnung
	my $vergangende_sekunden = $now - $last;
	my $vergangende_stunden = $vergangende_sekunden / 60 / 60;
	
	my $verbrauch = $Verbrauch_pro_stunde * $vergangende_stunden * $ventil / 100;
	my $verbrauchOhneSvne = $verbrauch;
	
	if ($fensterstatus eq "offen" && $raumtemp < $solltempFensterZu) {
		$verbrauchOhneSvne = $Verbrauch_pro_stunde * $vergangende_stunden;
	}
	
	## Aufsummieren
	$Energie_verbraucht_30 += $verbrauch;
  	$Energie_verbraucht_7 += $verbrauch;
  	$Energie_verbraucht += $verbrauch;
  	fhem ("set Sven_EnergieManager_$room verbrauchMonat $Energie_verbraucht_30");
  	fhem ("set Sven_EnergieManager_$room verbrauchWoche $Energie_verbraucht_7");
  	fhem ("set Sven_EnergieManager_$room verbrauchTag $Energie_verbraucht");
	
	$Energie_ohneSven_30 += $verbrauchOhneSvne;
	$Energie_ohneSven_7 += $verbrauchOhneSvne;
	$Energie_ohneSven += $verbrauchOhneSvne; 
	fhem ("set Sven_EnergieManager_$room ohneSevenMonat $Energie_ohneSven_30");
	fhem ("set Sven_EnergieManager_$room ohneSevenWoche $Energie_ohneSven_7");
	fhem ("set Sven_EnergieManager_$room ohneSevenTag $Energie_ohneSven");

	my $Energie_einsparung_30 = $Energie_ohneSven_30 - $Energie_verbraucht_30;
	my $Energie_einsparung_7  = $Energie_ohneSven_7  - $Energie_verbraucht_7;
	my $Energie_einsparung    = $Energie_ohneSven    - $Energie_verbraucht;
	fhem ("set Sven_EnergieManager_$room einsparungMonat $Energie_einsparung_30");
	fhem ("set Sven_EnergieManager_$room einsparungWoche $Energie_einsparung_7");
	fhem ("set Sven_EnergieManager_$room einsparungTag $Energie_einsparung");
	
}

sub UIgeneration ($) {
	my ($raum) = @_;
	my $ok = mkdir("./www/tablet/".$raum);

	if ($ok) {
		print "\nGeneriere Tablet-UI für Raum $raum\n";
	
		## lesen
		open(my $index,'<:encoding(UTF-8)',"./www/tablet/index.html")|| die "./www/tablet/index.html nicht gefunden\n";
		my $string = "";
		while (my $row = <$index>) {
			$string .= $row;
		}
		close($index);
		
		## neuer Teil
		my $newstring = "<div class='row'> 
							<div data-type='pagetab' 
								data-url='".$raum."/uebersicht_".$raum.".html' 
								data-icon='fs-hue_room_frontdoor' 
								class='cell'> 
							</div> 
						</div> 
						<div class='row'> 
							<div data-type='label' data-text-size='18'> 
								".$raum."
							</div> 
						</div> 
						<!-- weitere -->";

		$string =~ s/<!-- weitere -->/$newstring/g;
		
		## schreiben
		open($index,'>:encoding(UTF-8)',"./www/tablet/index.html")|| die "./www/tablet/index.html nicht gefunden\n";
		print $index $string;
		close($index);
		
		my $in_path = "./www/tablet/Vorlagen/";
		my $out_path = "./www/tablet/".$raum."/";
		my $html = ".html";
		my @filenames=("auswertung","feedback","info","menu","uebersicht");
		foreach (@filenames) {
			my $filename = $_; 
			
			## lesen
			open(my $in_file,'<:encoding(UTF-8)',$in_path.$filename.$html)|| die $in_path.$filename.$html." nicht gefunden\n";
			my $content = "";
			while (my $row = <$in_file>) {
				$content .= $row;
			}
			close($in_file);
			
			$content =~ s/RaumNR/$raum/g;
			
			## schreiben
			open(my $out_file,'>:encoding(UTF-8)',$out_path.$filename."_".$raum.$html)|| die $out_path.$filename.$html." konnte nicht angelegt werden\n";
			print $out_file $content;
			close($out_file);
		}	
	
	}
}

sub deleteUIroom ($) {
	my ($raum) = @_;
	my $ok = -d("./www/tablet/".$raum);

	if ($ok) {
		print "\nLösche TabletUI Raum $raum\n";
	
		## lesen
		open(my $index,'<:encoding(UTF-8)',"./www/tablet/index.html")|| die "./www/tablet/index.html nicht gefunden\n";
		my $string = "";
		while (my $row = <$index>) {
			$string .= $row;
		}
		close($index);
		
		## neuer Teil
		my $newstring = "<div class='row'> 
							<div data-type='pagetab' 
								data-url='".$raum."/uebersicht_".$raum.".html' 
								data-icon='fs-hue_room_frontdoor' 
								class='cell'> 
							</div> 
						</div> 
						<div class='row'> 
							<div data-type='label' data-text-size='18'> 
								".$raum."
							</div> 
						</div>";

		$string =~ s/$newstring/ /g;
		
		## schreiben
		open($index,'>:encoding(UTF-8)',"./www/tablet/index.html")|| die "./www/tablet/index.html nicht gefunden\n";
		print $index $string;
		close($index);
		
		## löschen
		my $out_path = "./www/tablet/".$raum."/";
		my $html = ".html";
		my @filenames=("auswertung","feedback","info","menu","uebersicht");
		foreach (@filenames) {
			my $filename = $_; 
			unlink($out_path.$filename."_".$raum.$html);
		}
		rmdir "./www/tablet/".$raum;
	}
}
1;
