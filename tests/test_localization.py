import importlib.util
import json
import re
import struct
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('build_languages', ROOT / 'tools/build_languages.py')
LANGUAGES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LANGUAGES)


class LocalizationTests(unittest.TestCase):
    def test_catalogue_lookups_stay_fast_on_win16(self):
        # Each lookup rereads the catalogue: a 128-byte Text buffer and a scan
        # past the section made Desktop Properties take ten seconds to open.
        catalog = (ROOT / 'src/portable/language_catalog.pas').read_text()
        self.assertIn('SetTextBuf(Source, ReadBuffer^, ReadBufferSize);', catalog)
        self.assertIn('if ReadBuffer = nil then New(ReadBuffer);', catalog)
        self.assertIn('if CompareText(ActiveSection, Section) = 0 then Exit;', catalog)
        langui = (ROOT / 'vcl/langui.pas').read_text()
        self.assertIn('if Value <> Original then Texts[J] := Value;', langui)
        self.assertIn('if Value <> Original then SetStrProp(Item, Prop, Value);', langui)
        probe = (ROOT / 'tests/pascal/test_language_catalog.pas').read_text()
        self.assertIn('a lookup ends with its section', probe)

    def test_placeholder_order_and_escaped_percent_are_preserved(self):
        self.assertEqual(LANGUAGES.placeholders('%d: %s (%%)'), ['%d', '%s'])
        self.assertNotEqual(LANGUAGES.placeholders('%d %s'), LANGUAGES.placeholders('%s %d'))

    def test_dfm_truncation_is_rejected(self):
        with self.assertRaises(ValueError):
            LANGUAGES.DfmReader(b'TPF0\x05AB').text()

    def test_requested_dfm_metadata_preserves_integer_types_without_changing_captions(self):
        def short(value):
            raw = value.encode('cp1252')
            return bytes([len(raw)]) + raw
        for kind, fmt, number in ((2, '<b', -1), (3, '<h', 201), (4, '<i', 70000)):
            data = (b'TPF0' + short('TForm') + short('Form') + short('Caption') +
                    b'\x06' + short('Title') + short('HelpContext') + bytes([kind]) +
                    struct.pack(fmt, number) + b'\0\0')
            regular, metadata = {}, {}
            LANGUAGES.DfmReader(data).component(regular)
            LANGUAGES.DfmReader(data, ('HelpContext',)).component(metadata)
            self.assertEqual(regular, {'TForm.Form.Caption': 'Title'})
            self.assertEqual(metadata['TForm.Form.HelpContext'], number)
            self.assertEqual(metadata['TForm.Form.Caption'], 'Title')

    def test_unnamed_components_get_no_shared_key(self):
        # Notebook pages have no name; their captions come from Pages.Strings.
        # A shared 'TForm..Caption' key once renamed a radio group's buttons.
        def short(value):
            raw = value.encode('cp1252')
            return bytes([len(raw)]) + raw
        data = (b'TPF0' + short('TForm') + short('Form') + short('Caption') + b'\x06' + short('Title') +
                b'\0' + short('TPage') + short('') + short('Caption') + b'\x06' + short('Fonts') +
                b'\0\0\0')
        result = {}
        LANGUAGES.DfmReader(data).component(result)
        self.assertEqual(result, {'TForm.Form.Caption': 'Title'})
        langui = (ROOT / 'vcl/langui.pas').read_text(encoding='cp1252')
        self.assertEqual(langui.count("  if Item.Name <> '' then\n"), 2)

    def test_catalogues_have_shared_ids_and_ansi_line_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            LANGUAGES.build(output)
            report = json.loads((output / 'coverage.json').read_text())
            for code in ('en', 'de', 'fr'):
                data = (output / f'{code}.LNG').read_bytes()
                self.assertIn(f'Code={code}\r\n'.encode(), data)
                self.assertIn(b'[TaskManager]\r\n', data)
                self.assertIn(b'[FileManager]\r\n', data)
                self.assertGreater(report[code]['entries'], 900)
                self.assertTrue(all(len(line) <= 250 for line in data.split(b'\r\n')))
            self.assertTrue(any('format mismatch' in item for item in report['fr']['omitted']))
            # Translations taken from the resources of translated releases.
            for code, minimum in (('nl', 900), ('pl', 900), ('it', 900), ('es', 700)):
                self.assertGreater(report[code]['entries'], minimum)
            self.assertIn(b'CodePage=1250\r\n', (output / 'pl.LNG').read_bytes())
            self.assertIn('1027=Przeniesienie %s do kosza jest niemo\u017cliwe\r\n'.encode('cp1250'),
                          (output / 'pl.LNG').read_bytes())
            self.assertIn(b'1026=Willkommen\r\n', (output / 'de.LNG').read_bytes())
            self.assertIn(b'1026=Welkom\r\n', (output / 'nl.LNG').read_bytes())

    def test_stale_translations_give_way_to_project_translations(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            LANGUAGES.build(output)
            french = (output / 'fr.LNG').read_bytes().decode('cp1252')
            spanish = (output / 'es.LNG').read_bytes().decode('cp1252')
            polish = (output / 'pl.LNG').read_bytes().decode('cp1250')
            # 3.3 had General/Display/Fonts where today's dialog has Wallpaper/Icons/...
            self.assertIn("TDeskPropDlg.TabPanel.Tabs.Strings.0=Fond d'\u00e9cran\r\n", french)
            # Spanish 2.3 put its licence text where today's About box shows the DOS version.
            self.assertIn('TAboutBox.Label2.Caption=Versi\u00f3n de MS-DOS:\r\n', spanish)
            # Historical text that fails a check falls back to the project translation.
            self.assertIn('TAboutBox.LicenceLabel.Caption=To jest wolne oprogramowanie;', polish)
            self.assertIn('TFileSysPropDlg.Label19.Caption=d\u00e9cimales pour les tailles en Ko\r\n', french)
            report = json.loads((output / 'coverage.json').read_text())
            self.assertGreater(report['es']['stale'], 300)
            for code in ('fr', 'nl', 'pl', 'it', 'es'):
                self.assertGreater(report[code]['entries'], 900)

    def test_project_translations_match_english_keys_and_formats(self):
        english = LANGUAGES.directory_forms(ROOT / 'src')
        names = dict(re.findall(r'^\s*(S\w+)\s*=\s*(\d+)\s*;', (ROOT / 'src/locale.pas').read_text(), re.M))
        messages = {names[k]: v for k, v in LANGUAGES.resource_strings(ROOT / 'src').items() if k in names}
        extra = json.loads((ROOT / 'locales/extra.json').read_text())['en']
        for path in sorted((ROOT / 'locales/translated').glob('*.json')):
            codepage = f"cp{LANGUAGES.CODEPAGES.get(path.stem, 1252)}"
            for section, entries in json.loads(path.read_text(encoding='utf-8')).items():
                baseline = ({**english, **extra['Forms']} if section == 'Forms' else
                            messages if section == 'Strings' else extra[section])
                for key, value in entries.items():
                    with self.subTest(language=path.stem, key=key):
                        self.assertIn(key, baseline)
                        self.assertEqual(LANGUAGES.placeholders(value), LANGUAGES.placeholders(baseline[key]))
                        value.encode(codepage)

    def test_installer_uses_one_payload_and_persists_language(self):
        descriptor = (ROOT / 'install/install.ini').read_text()
        self.assertIn('Config=CALMIRA.INI|Language|Selected', descriptor)
        for code in ('en', 'de', 'fr', 'nl', 'it', 'es', 'pl'):
            self.assertIn(f'LANG\\{code}.LNG', descriptor)
            self.assertIn(f'Choice={code}|', descriptor)


if __name__ == '__main__':
    unittest.main()
