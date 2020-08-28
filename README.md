# SVEN-FHEM-Server-Files

The PM-Files and the HTLM-Templates needed to be added to FHEM if you want to use SVEN.

See https://projekt-sven.github.io/ for more Infos.

You need to install followwed packages in FHEM:
- FHEM Tablet UI (see https://wiki.fhem.de/wiki/FHEM_Tablet_UI)

Installation:
1.  Copy the content of this Repository into your Folder where you installed FHEM.
2.  Run the Perlfunktion `Sven_init()` in FHEM.

## Automatisierung

Die Automatisierung in FHEM ist über zwei Moduldateien definiert: eine für die LSF-Schnittstelle und eine für die eigentliche Automatisierung. In beiden Dateien sind verschiedene Perlfunktionen definiert, um die Automatisierung umzusetzen. Das System ist dabei so konzipiert, das die Anwendung für den Administrator so einfach wie möglich ist. Dieser muss zu Beginn nur die Funktion „Sven_init“ ausführen und kann danach über die Benutzeroberfläche mit dem System interagieren. 

Über das FHEM-Gerät „Sven_Manager“ können dann einfach Räume hinzugefügt und entfernt werden. Wichtig ist dabei, dass der Name mit dem im LSF hinterlegten Namen des Raumes übereinstimmt (wobei Leerzeichen durch Unterstriche ersetzt werden). Danach werden automatisiert verschiedene Geräte in FHEM angelegt, die die Automatisierung und Steuerung übernehmen, sowie ein Webinterface für den Raum generiert (siehe 6.6). 

Die wichtigsten Geräte im Raum sind die vier Manager Geräte. Diese enthalten jeweils die Daten und dienen zur Steuerung. Der erste Manager ist der Energiemanager, er speichert den Verbrauch. Zur Berechnung ist es allerding notwendig, dass das Reading “verbrauchProStunde” über das Nutzerinterface gesetzt wird. Der Wert sollte den KWh entsprechen, die verbraucht werden, wenn die Heizung eine Stunde mit voller Leistung heizt. 

Der Fenstermanager dient zur Fenstersteuerung. Er enthält den aktuellen Status, sowie ein Reading, dass eine evtl. Vorhandene Fenstersteuerung ansteuert. Da zur Laufzeit des Projektes nicht die Möglichkeit zur Installation einer Ansteuerung bestand, ist letzteres nur Vorbereitet und das Notify “Sven_UpdateFenstersteuerung” muss in der Perlfunktion “Sven_UpdateFenstersteuerung” für ein echtes Gerät entsprechend angepasst werden. 

Als dritter Manager existiert der Temperaturmanager, um die Raumtemperatur zu steuern. Unterstützt wird dieser dabei von dem virtuellen Gerät “Sven_HMVirtuell”, welches zur Kommunikation mit den HM-Thermostaten notwendig ist. 

Der letzte und wichtigste Manager ist der Raummanager. Über ihn können die in Abschnitt 6.2 genannten Geräte dem Raum hinzugefügt werden, nachdem diese im Voraus in FHEM angelegt wurden. Die weitere Ansteuerung und Zustandsüberwachung der Geräte erfolgt anschließend vollautomatisch. 

Des Weiteren werden noch eine Notify- und At-Geräte im Raum angelegt, die zur Zustandsüberwachung und automatisierten Ansteuerung dienen angelegt. Zusätzlich ist noch anzumerken, dass das System in den Pausen automatisch die Fenstersteuerung (aktuell ohne reale Geräte) anspricht die Fenster entsprechend der Wetterlage zum Lüften öffnet. Dabei gilt das die Fenster nur bei einer Regenwahrscheinlichkeit von unter 80% automatisch geöffnet werden und bei Temperaturen unter 0°C bzw. Über 30°C nur für 5 Minuten und an ansonsten für 15 Minuten geöffnet werden. 

## Nutzerschnittstelle
Für das Nutzerinterface wurde das Framework FHEM Tablet UI verwendet. Die Verwendung eines vorhandenen Frameworks ersparte viel Zeit bei der Implementierung. Eine Installation des Frameworks erfolgt in simplen Schritten, wie im detailreichen Wiki-Artikel nachgelesen werden kann. Das Framework ermöglicht es, in FHEM integrierte Geräte zu steuern und ihren Status anzeigen zu lassen. Geliefert werden diverse HTML-, CSS- und JavaScript-Dateien, welche nach Belieben angepasst werden können. Die Konfiguration grafischer Elemente erfolgt mit einer Vielzahl vordefinierter widgets, welche in HTML-Dateien eingebunden werden. Zur Realisierung der Nutzeroberfläche wurden die folgenden Dateien implementiert: index-html, menu.html, uebersicht.html, auswertung.html, info.html und feedback.html. Diese Dateien spiegeln die in Abschnitt 4.4 beschriebenen Bereiche der Nutzeroberfläche wider. Die letzten fünf Dateien werden dabei für jeden Raum spezifisch generiert, um eine Unterscheidung zwischen den Geräten der einzelnen Räume zu ermöglichen. Jede Datei integriert dabei ihr jeweiliges Menü an den linken Rand der Oberfläche. Es ist auch zu beachten, dass das Layout jeder Datei in x-Richtung fünf Blöcke und in y-Richtung zwei Blöcke groß ist, damit die einzelnen Abschnitte möglichst gleichmäßig aussehen. Da sich in der Auswertungsanzeige drei Elemente untereinander befinden anstelle von zwei, wurde hier die y-Größe auf sechs Blöcke gesetzt. 

### Index.html 

Der Einstieg in die Nutzeroberfläche erfolgt standardmäßig über die index.html-Datei. Diese wurde verwendet, um dem Nutzer die Auswahl eines Raumes zu ermöglichen. Die einzelnen Elemente werden dabei bestehend aus einem Pagetab, welcher die Verknüpfung zu einer anderen Datei realisiert und die aktuell geladene Datei durch diese austauscht, sowie einem Label zur Beschriftung in jeweils eine eigene Reihe des Layouts eingefügt. Es wurde ein Label verwendet, da die Schriftgröße der Pagetab-Beschriftung nicht angepasst werden kann. Das Auswählen eines Raumes lädt die jeweilige uebersicht.html-Datei des Raumes. Um die Verwendung des Nutzerinterfaces auf mobilen Endgeräten zu gestatten, wurden zwei meta-Tags eingefügt. In den einzelnen Dateien wurde das Gridster-Layout angewendet. Die einzelnen Elemente dieses Layouts können ohne das Meta-Tag “gridster_disable” flexibel verschoben werden. Damit dies nicht möglich ist, wurde das Meta-Tag eingefügt. Beim Bedienen der Elemente werden dem Nutzer Toast-Nachrichten angezeigt. Diese wurden durch das Meta-Tag “toast content=’0’ unterbunden, um den Nutzer mit den angezeigten FHEM-Befehlen nicht zu verwirren. Zuletzt verfügt die Datei noch über eine JavaScript-Funktion zum Ermitteln der Raumbezeichnung aus dem Link und einer Funktion, welche das Feedback des Nutzers aus den im Feedback-Tab befindlichen Selektoren ausliest und an die Datenbank mittels eines XML-Http-Requests zur Verarbeitung weitergibt.  

### Menu.html 

Das Menü dient als Verknüpfung der einzelnen anderen Dateien, um zwischen diesen hin- und herwechseln zu können. Auch hier werden Pagetabs zur Navigation angewendet. Unter den Menüpunkten wird das Logo eingebunden. Das Menü selbst wird in jeder Seite als Template geladen.  

### Uebersicht.html 

Diese Datei ist die erste, welche nach der Raumauswahl aufgerufen wird. Mittels dieser Seite werden die Steuerungsmöglichkeiten angezeigt und Graphen zur zeitlichen Raumnutzung, Öffnungszeiträume der Fenster, Raumtemperatur und Thermostateinstellung angezeigt. Die Steuerung der Heizung wird dabei über einen Spinner realisiert, welcher die Solltemperatur im Temperaturmanager setzt und zur Anzeige ausliest. Das Setzen der Temperatur wurde dabei auf 23°C beschränkt, da dies für ausreichend befunden wurde und eine höhere Temperatur mehrheitlich als unangenehm empfunden wird. Hierbei ist zu beachten, dass bei einem Umstellen der Temperatur das Umsetzen durch das Funkthermostat oftmals etliche Sekunden dauert und das Spinner-Element währenddessen noch den alten Status ausliest und anzeigt. Der Status des Heizungsventils wird ebenfalls visualisiert. In der darunter befindlichen Reihe wird der Status der Fenster mittels eines Switches visualisiert, welcher die Eigenschaft readonly hat. Das bedeutet, dass dieses Element lediglich zur Anzeige dient. Darunter befindlich kann die Fenstersteuerung genutzt werden, welche dem Fenstermanager entsprechende Befehle erteilt.  Abschließend wird die nächste planmäßige Lüftung des Raumes angezeigt. Auf der rechten Seite befinden sich dann die angesprochenen Grafen, welche die zu visualisierenden Daten aus den Log-Dateien der jeweiligen Manager auslesen. 

### Info.html 

Im Info-Tab wird der Nutzer mittels eines Textes in einem einzelnen Label aufgeklärt, was der Name “SVEN” bedeutet und welche Möglichkeiten ihm durch die grafische Nutzeroberfläche geboten werden. 
