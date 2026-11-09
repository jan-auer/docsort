#!/usr/bin/env python3
"""Writes folders.txt: the folder tree of a fictional household archive for docsort's examples and previews.

All of it is invented and describes no real archive or person (see `no-real-data-in-repo` in
docs/decisions.md). The household: Konrad and Margit Weißenbacher, in their sixties, renting a flat at
Brunnfeldgasse 14/3 in the made-up town of Wettelau. Konrad retired from the town's survey office in 2032 and keeps
the books of his choir; Margit teaches music part-time at a private school; their son Matthias studies abroad. They
have an allotment garden, a dog called Fritzi and no car. Every company, club, school and doctor is made up, and all
dates fall in 2031 to 2033.

Run `python3 make_sample_archive.py`; it writes folders.txt next to this script, one folder path per line, parents
before children, sorted.
"""
import os

YEARS = ["2031", "2032", "2033"]


def years(*names, start="2031"):
    """Year folders from `start` to 2033, each optionally holding the same subfolders."""
    sub = {n: {} for n in names}
    return {y: dict(sub) for y in YEARS if y >= start}


def quarters(start="2031-Q1", end="2033-Q4"):
    out = {}
    for y in YEARS:
        for q in range(1, 5):
            name = f"{y}-Q{q}"
            if start <= name <= end:
                out[name] = {}
    return out


def flat(*names):
    return {n: {} for n in names}


def years_by_quarter(start="2031"):
    """Year folders, each split into its four quarters."""
    return {y: quarters(f"{y}-Q1", f"{y}-Q4") for y in YEARS if y >= start}


TREE = {
    "Bank & Geld": {
        "Girokonto Bürgerbank": {**quarters(), **flat("Kontovertrag & Karten", "Daueraufträge", "Online-Banking")},
        "Sparbuch Bürgerbank": years(),
        "Kreditkarte": {**years_by_quarter(), "Kartenvertrag": {}},
        "Haushaltsbuch": years_by_quarter(),
        "Überweisungen Matthias": years(),
        "Notgroschen Tagesgeld": flat("Vertrag", "Zinsmitteilungen"),
    },
    "Wohnung Brunnfeldgasse": {
        "Mietvertrag": flat("Nachträge", "Übergabeprotokoll"),
        "Mietvorschreibungen": years(),
        "Betriebskosten": years(),
        "Genossenschaft Heimstatt": flat("Hausversammlungen", "Mitteilungen", "Hausordnung", "Mitgliedsanteil"),
        "Reparaturen": flat(
            "2031-11 Heizkörperventil Wohnzimmer",
            "2032-03 Wasserhahn Küche",
            "2032-08 Wasserschaden Bad",
            "2033-02 Fensterdichtungen",
            "2033-07 Gegensprechanlage",
        ),
        "Einrichtung": flat("Küche", "Schlafzimmer", "Lampen", "Teppiche & Vorhänge", "Arbeitszimmer Konrad"),
        "Kellerabteil": {},
        "Rundfunkbeitrag": years(),
        "Strom Stadtwerke": {"Vertrag": {}, "Jahresabrechnungen": years(), "Teilbeträge": years()},
        "Fernwärme Stadtwerke": {"Vertrag": {}, "Jahresabrechnungen": years(), "Teilbeträge": years()},
        "Zählerstände": years(),
    },
    "Arbeit Margit": {
        "Dienstvertrag Schulverein Lerchenfeld": flat("Nachträge", "Lehrverpflichtung"),
        "Gehaltszettel": years(),
        "Jahreslohnzettel": years(),
        "Stundenpläne": flat("Schuljahr 2031-32", "Schuljahr 2032-33", "Schuljahr ab Herbst 2033"),
        "Fortbildungen": flat(
            "2031-11 Stimmbildung mit Kindern",
            "2032-04 Chorleitung Grundkurs",
            "2032-10 Rhythmik Werkstatt",
            "2033-03 Tagung Musikpädagogik",
            "2033-08 Sommerakademie Blockflöte",
        ),
        "Konzerte & Vorspiele": flat(
            "2031-12 Adventvorspiel",
            "2032-06 Schlusskonzert",
            "2032-12 Adventvorspiel",
            "2033-06 Schlusskonzert",
        ),
        "Schule Mitteilungen": years(),
        "Betriebsrat": {},
        "Dienstreisen & Exkursionen": years(start="2032"),
    },
    "Pension Konrad": {
        "1. Antrag Ruhestand": flat("Formulare", "Dienstzeitenbestätigung", "Beratungsgespräch"),
        "2. Bescheid Ruhegenuss": flat("Bescheid", "Berechnungsblatt"),
        "3. Laufende Bezüge": years(start="2032"),
        "4. Neuberechnung & Nachzahlung": {},
        "Dienstzeit Vermessungsamt": flat("Dienstzeugnis", "Jubiläen", "2032-06 Abschiedsfeier"),
        "Pensionistenausweis": {},
    },
    "Steuern": {
        "Steuerausgleich": years("Konrad", "Margit"),
        "Spendenbestätigungen": years(),
        "Krankheitskosten Belege": years("Konrad", "Margit"),
        "Finanzamt Schreiben": {},
        "Kirchenbeitrag absetzbar": years(),
    },
    "Gesundheit": {
        "Konrad": flat(
            "Hausarzt Dr. Rameis",
            "Augenarzt & Brillen",
            "Zahnarzt",
            "Labor & Befunde",
            "Physiotherapie",
            "Hörtest",
            "2033-05 Kur Bad Seetal",
        ),
        "Margit": flat(
            "Hausarzt Dr. Rameis",
            "Zahnarzt",
            "Physiotherapie",
            "Frauenärztin",
            "HNO & Stimme",
            "Labor & Befunde",
        ),
        "Gesundheitskasse Ilmtal": {"Rückerstattungen": years(), "e-card": {}, "Schreiben": {}},
        "Impfpässe": {},
        "Patientenverfügung": {},
        "Apotheke Dauerrezepte": years(),
    },
    "Versicherungen": {
        "Haushaltsversicherung Hollerau": flat("Polizze", "Prämien", "Schadensfälle"),
        "Privathaftpflicht": flat("Polizze", "Prämien"),
        "Hundehaftpflicht Fritzi": flat("Polizze", "Nachträge"),
        "Unfallversicherung Konrad": flat("Polizze", "Prämien"),
        "Rechtsschutz": flat("Polizze", "Fälle"),
        "Reiseversicherung": flat("Polizze", "2032-09 Schadensmeldung Gepäck"),
        "Instrumentenversicherung Klavier": flat("Polizze", "Wertgutachten"),
        "Ablebensversicherung": flat("Polizze", "Jahresmitteilungen"),
    },
    "Mobilität": {
        "Jahreskarte Regio Plus": {},
        "Bahntickets": years(),
        "rollmit Carsharing": {"Mitgliedschaft": {}, "Abrechnungen": years()},
        "Fahrräder": flat(
            "Trekkingrad Konrad",
            "E-Bike Margit",
            "Radwerkstatt Speiche",
            "Zubehör & Schlösser",
            "Fahrradanhänger",
        ),
        "Rufbus & Taxi": years(),
        "Fahrgastrechte": {},
    },
    "Kommunikation": {
        "Ilmnet Internet": flat("Vertrag", "Rechnungen", "Router & Technik"),
        "Handy Konrad parla mobil": flat("Vertrag", "Rechnungen"),
        "Handy Margit parla mobil": flat("Vertrag", "Rechnungen"),
        "Zeitungsabo Ilmtaler Rundschau": years(),
        "Abos & Mitgliedschaften online": {},
    },
    "Kleingarten Am Weidenbach": {
        "Pachtvertrag Parzelle 23": {},
        "Pacht & Wasser": {},
        "Vereinsmitteilungen": years(),
        "Gemeinschaftsarbeit": years(),
        "Gartenhütte": flat("2032-04 Dachpappe erneuert", "2033-06 Regentonne"),
        "Saatgut & Pflanzen": years(),
        "Werkzeug & Geräte": {},
        "Gartenbuch & Ernte": years(),
        "Gartenfeste": flat("2032-08 Sommerfest", "2033-08 Sommerfest"),
    },
    "Chor Liederkranz": {
        "Mitgliedschaft": {},
        "Kassa": {**years(), "Kassabuch": {}, "Kassaprüfung": years()},
        "Noten": {},
        "Probenpläne": years(),
        "Konzerte": flat(
            "2031-05 Frühjahrskonzert",
            "2031-12 Adventsingen",
            "2032-05 Frühjahrskonzert",
            "2032-12 Adventsingen",
            "2033-05 Frühjahrskonzert",
            "2033-12 Adventsingen",
        ),
        "Chorreisen": flat("2032-09 Chorreise Seetal", "2033-09 Chorfest Hochalm"),
        "Vorstand & Protokolle": years(),
        "Chronik": flat("Fotos", "Zeitungsberichte", "Entwürfe"),
        "Förderungen Gemeinde": years(),
    },
    "Musik Margit": {
        "Klavier": flat("Kaufvertrag", "Stimmungen Klavierbau Sonnleitner", "Reparaturen"),
        "Blockflöten": flat("Kaufbelege", "Wartung"),
        "Noten & Bücher": {},
        "Konzertbesuche": years(),
        "Kurse": flat("2032-07 Kammermusikwoche", "2033-07 Kammermusikwoche"),
    },
    "Hund Fritzi": {
        "Tierarzt": flat("Impfungen", "Behandlungen", "Zahnkontrolle", "Rechnungen"),
        "Hundeabgabe": years(),
        "Hundeschule Pfotenweg": flat("2031-05 Junghundekurs", "2032-04 Begleithundeprüfung", "Mitgliedsbeiträge"),
        "Futter & Zubehör": years(),
        "Chip & Heimtierausweis": {},
        "Hundepension & Sitter": {},
    },
    "Matthias": {
        "Studium Westerholm": {
            "Bewerbung & Zulassung": {},
            "1. Studienjahr": flat("Collegegeld", "Bestätigungen", "Wohnen", "Prüfungen"),
            "2. Studienjahr": flat("Collegegeld", "Bestätigungen", "Wohnen", "Prüfungen"),
            "3. Studienjahr": flat("Collegegeld", "Bestätigungen", "Wohnen", "Prüfungen"),
            "Auslandsversicherung": {},
        },
        "Familienbeihilfe": years(),
        "Unterhalt & Überweisungen": years(),
        "Besuche": flat("2031-12 Weihnachten daheim", "2032-07 Sommer daheim", "2033-07 Sommer daheim"),
        "Dokumente Matthias": flat("Reisepass Kopie", "Meldebestätigungen", "Zeugnisse"),
    },
    "Reisen": {
        "2031-08 Radtour Ilmtal": flat("Unterkünfte", "Karten"),
        "2031-10 Herbstwandern Seetal": {},
        "2032-02 Städtereise Sankt Veitsberg": flat("Bahn", "Hotel", "Museen"),
        "2032-05 Pfingsten Hochalm": {},
        "2032-09 Besuch Matthias Westerholm": flat("Bahn", "Unterkunft"),
        "2033-03 Thermenwochenende Bad Seetal": {},
        "2033-01 Langlaufwoche Hochalm": {},
        "2033-06 Wanderwoche Hochalm": flat("Anreise", "Unterkunft", "Wanderkarten"),
        "Reiseplanung Ideen": {},
    },
    "Ahnenforschung": {
        "Familie Weißenbacher": flat("Pfarrmatriken", "Fotos", "Briefe"),
        "Familie Gruber": flat("Pfarrmatriken", "Fotos", "Briefe"),
        "Familie Hollerer": flat("Pfarrmatriken", "Fotos"),
        "Familie Strassl": flat("Pfarrmatriken", "Fotos", "Briefe"),
        "Fahrten zu Ahnenorten": flat("2032-08 Pfarrarchiv Kirchberg", "2033-04 Friedhof Oberau"),
        "Anfragen Archive": flat("Landesarchiv", "Pfarre St. Ägidius", "Stadtarchiv Wettelau"),
        "Stammbaum": flat("Entwürfe", "Druckfassung"),
    },
    "Dokumente & Ausweise": {
        "Konrad": flat("Reisepass", "Personalausweis", "Geburtsurkunde", "Staatsbürgerschaftsnachweis", "Führerschein"),
        "Margit": flat("Reisepass", "Personalausweis", "Geburtsurkunde", "Staatsbürgerschaftsnachweis", "Führerschein"),
        "Heiratsurkunde": {},
        "Meldezettel": {},
        "Vorsorgevollmacht": {},
        "Testament & Verfügungen": {},
        "Wahlkarten": years(),
    },
    "Einkäufe & Garantien": {
        "Haushaltsgeräte": flat("Waschmaschine", "Kühlschrank", "Staubsauger", "Kaffeemaschine", "Nähmaschine", "Mikrowelle", "Bügeleisen"),
        "Elektronik": flat("Laptop Konrad", "Tablet Margit", "Fernseher", "Drucker & Scanner", "Kopfhörer"),
        "Kleidung & Schuhe": years(),
        "Online-Bestellungen": years(),
        "Geschenke": years(),
    },
    "Vereine & Ehrenamt": {
        "Stadtbücherei": {
            "Vereinbarung Ehrenamt": {},
            "Dienstpläne": quarters(start="2032-Q3"),
            "Lesepatenschaft": flat("Volksschule Kirchberg", "Seniorenheim Am Anger"),
            "Bücherflohmarkt": flat("2032-04 Flohmarkt", "2033-04 Flohmarkt"),
        },
        "Kirchenbeitrag Pfarre St. Ägidius": years(),
        "Naturschutzbund Ilmtal": years(),
        "Tierschutzverein Wettelau": years(),
        "Seniorentreff Brunnfeld": {},
        "Spenden": years(),
    },
    "! Abgeschlossen": {
        "Dienst Vermessungsamt bis 2032": {"Gehaltszettel": years(start="2031"), "Dienstreisen": {}, "Personalakt Kopien": {}},
        "Alte Wohnung Seegasse bis 2031": flat("Mietvertrag", "Kaution", "Übergabeprotokoll"),
        "Auto verkauft 2031": flat("Kaufvertrag Verkauf", "Abmeldung", "Versicherung Kündigung"),
        "Matura Matthias 2031": {},
        "Girokonto Hausbank bis 2031": {},
        "Handyvertrag alt": {},
    },
}


def walk(tree, prefix=""):
    for name, sub in tree.items():
        path = f"{prefix}/{name}" if prefix else name
        yield path
        yield from walk(sub, path)


def main():
    paths = sorted(set(walk(TREE)))
    too_deep = [p for p in paths if p.count("/") > 3]
    if too_deep:
        raise SystemExit(f"deeper than four levels: {too_deep[:3]}")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "folders.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(paths) + "\n")
    print(f"wrote {out}: {len(paths)} folders, {len(TREE)} top-level")


if __name__ == "__main__":
    main()
