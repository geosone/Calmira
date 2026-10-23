"""Keep the maintained RTF and native Windows 3.1 help in sync."""
import importlib.util
import os
from pathlib import Path
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('build_help', ROOT / 'tools/build_help.py')
HELP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HELP)
WHC = HELP.WHC


class HelpBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.output = Path(cls.directory.name) / 'calmira.hlp'
        with patch.dict(os.environ, {'SOURCE_DATE_EPOCH': '946684800'}):
            cls.report = HELP.build(cls.output)
        cls.data = cls.output.read_bytes()
        cls.helpfile = WHC.HelpFile(cls.data)
        cls.records = WHC.read_topics(cls.helpfile.file('|TOPIC'))

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def test_rebuild_is_deterministic_and_matches_checked_in_help(self):
        with patch.dict(os.environ, {'SOURCE_DATE_EPOCH': '946684800'}):
            HELP.build(self.output)
        self.assertEqual(self.data, self.output.read_bytes())
        self.assertEqual(self.data, (ROOT / 'help/calmira.hlp').read_bytes())

    def test_complete_topic_table_picture_and_link_sets(self):
        self.assertEqual(self.report['topics'], 64)
        self.assertEqual(self.report['reachable_topics'], self.report['topics'])
        self.assertEqual(self.report['tables'], 221)
        self.assertEqual(self.report['pictures'], 26)
        self.assertGreaterEqual(self.report['links'], 310)
        self.assertEqual(self.report['maps'], 25)

    def test_historical_contexts_and_numeric_help_calls_still_resolve(self):
        old = WHC.HelpFile((ROOT / 'vendor/upstream/calmira-reborn/HELP/CALMIRA.HLP').read_bytes())
        hashes = lambda hf: {key for key, offset in WHC.read_btree(
            hf.file('|CONTEXT'), WHC.Reader.s32, WHC.Reader.u32)}
        self.assertTrue(hashes(old).issubset(hashes(self.helpfile)))
        numbers = lambda hf: {struct.unpack_from('<i', hf.file('|CTXOMAP'), 2 + index * 8)[0]
                              for index in range(struct.unpack_from('<H', hf.file('|CTXOMAP'))[0])}
        self.assertEqual(numbers(self.helpfile), numbers(old) | {201, 900, 901, 902, 903})

    def test_popup_context_alias_resolves_to_computer_topic(self):
        maps = self.helpfile.file('|CTXOMAP')
        entries = dict(struct.unpack_from('<iI', maps, 2 + index * 8)
                       for index in range(struct.unpack_from('<H', maps)[0]))
        self.assertEqual(entries[201], entries[21])
        self.assertEqual(self.report['form_help_contexts'], 23)
        self.assertEqual(self.report['form_help_files'], 1)
        self.assertEqual(self.report['literal_help_jumps'], 5)

    def test_help_call_audit_rejects_missing_form_context_file_and_literal_jump(self):
        def short(value):
            raw = value.encode('cp1252')
            return bytes([len(raw)]) + raw

        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            for context, filename, message in (
                (9999, 'CALMIRA.HLP', 'unmapped'),
                (21, 'OLD.HLP', 'unexpected help filename')):
                (source / 'form.dfm').write_bytes(
                    b'TPF0' + short('TForm') + short('Form') + short('HelpContext') +
                    b'\x03' + struct.pack('<h', context) + short('HelpFile') +
                    b'\x06' + short(filename) + b'\0\0')
                with self.subTest(context=context), self.assertRaisesRegex(ValueError, message):
                    HELP.audit_help_calls(self.data, source)
            (source / 'form.dfm').unlink()
            (source / 'form.pas').write_text("Application.HelpJump('MissingTopic');")
            with self.assertRaisesRegex(ValueError, 'undefined HelpJump target'):
                HELP.audit_help_calls(self.data, source)

    def test_contents_menu_handlers_do_not_dereference_active_control(self):
        for filename, owner in (('iconwin.pas', 'TIconWindow'), ('opendlg.pas', 'TOpenDialogExFrm')):
            text = (ROOT / 'src' / filename).read_text(encoding='cp1252')
            handler = text.split(f'procedure {owner}.ContentsClick(Sender: TObject);', 1)[1].split('end;', 1)[0]
            with self.subTest(source=filename):
                self.assertIn("Application.HelpJump('Contents');", handler)
                self.assertNotIn('ActiveControl', handler)

    def test_literal_jump_scan_ignores_comments_strings_and_dynamic_arguments(self):
        text = ("{ Application.HelpJump('Comment'); }\n"
                "(* Application.HelpJump('Comment'); *)\n"
                "// Application.HelpJump('Comment');\n"
                "Log('Application.HelpJump(''Quoted'')');\n"
                "Application.HelpJump(Target);\n"
                "Application {comment}.HelpJump('Contents');\n"
                "application.helpjump('It''s literal');")
        self.assertEqual(list(HELP.literal_help_jumps(text)), ['Contents', "It's literal"])

    def test_all_contents_variants_link_to_status_and_practical_guides(self):
        contexts = dict(WHC.read_btree(self.helpfile.file('|CONTEXT'), WHC.Reader.s32, WHC.Reader.u32))
        required = {WHC.ctxhash(name) & 0xffffffff for name in (
            'ReloadedStatus', 'OpenLFNQuickStart', 'ReloadedGroups', 'ReloadedTroubleshooting')}
        variants = [name for name in (
            'Contents', 'ContentsExpanded', 'ContentsWelcome', 'ContentsUsersGuide',
            'ContentsAdvanced', 'ContentsDeveloper', 'ContentsEpilogue')]
        for name in variants:
            offset = contexts[WHC.ctxhash(name)]
            links = set()
            active = False
            for index, (pos, off, kind, record) in enumerate(self.records):
                if kind == 2:
                    active = index + 1 < len(self.records) and self.records[index + 1][1] == offset
                elif active and kind in (0x20, 0x23):
                    links.update(item[2] for item in record[1]
                                 if item[0] == 'cmd' and item[1].startswith('jump'))
            with self.subTest(contents=name):
                self.assertTrue(required.issubset(links))

    def test_navigation_accepts_cycles_but_rejects_orphans_and_invalid_targets(self):
        self.assertEqual(HELP.check_navigation({0: {1}, 1: {0}}, 0), 2)
        for graph, start, message in (
            ({0: set(), 1: set()}, 0, 'unreachable'),
            ({0: {2}}, 0, 'outside'),
            ({0: set()}, 2, 'contents')):
            with self.subTest(graph=graph), self.assertRaisesRegex(ValueError, message):
                HELP.check_navigation(graph, start)

    def test_practical_guides_have_own_topics_and_links(self):
        pages = {}
        title = None
        for pos, off, kind, record in self.records:
            if kind == 2:
                title = record[1][0] if record[1] else None
                if title:
                    pages[title] = []
            elif kind in (0x20, 0x23) and title:
                pages[title].extend(item[1] for item in record[1] if item[0] == 'text')
        expected = {
            'OpenLFN and ZIP quick start': ('Stop hook and exit', 'Enter', 'INSTALL.EXE /U'),
            'Program Manager groups and application language': ('one-way', 'SyncProgramGroups=False', '[Language]'),
            'Reloaded troubleshooting and safe recovery': ('VSHARE', 'CLFN.SAV', 'uncompressed'),
        }
        for title, values in expected.items():
            with self.subTest(topic=title):
                text = '\n'.join(pages[title])
                for value in values:
                    self.assertIn(value, text)

    def test_native_tables_seek_to_each_cells_own_text(self):
        tables = [record for pos, off, kind, record in self.records if kind == 0x23]
        paragraphs = [item[1] for table in tables for item in table[1]
                      if item[0] == 'para' and item[1].get('column') != -1]
        self.assertTrue(any(p['text_offset'] > 0 for p in paragraphs))
        first = tables[0][1]
        self.assertIn(('text', 'Welcome'), first)
        self.assertEqual(next(item for item in first if item[0] == 'table')[3], [(68, 11), (516, 11)])
        self.assertTrue(all(p['table_size'] >= 6 for p in paragraphs))

    def test_updated_banner_is_embedded_not_just_copied_beside_help(self):
        bitmap = WHC.bmp_to_lp((ROOT / 'help/banner.bmp').read_bytes())
        self.assertIn(bitmap, [self.helpfile.file(name) for name in self.helpfile.files
                               if name.startswith('|bm')])

    def test_current_product_and_extensions_are_documented(self):
        text = '\n'.join(item[1] for pos, off, kind, record in self.records
                         if kind in (0x20, 0x23) for item in record[1] if item[0] == 'text')
        for value in ('Calmira Reloaded', 'OLFNLOAD.EXE', 'DESCRIPT.ION', 'INSTALL.INI',
                      'ProgramGroupsCaption', 'read-only', 'Free Pascal', 'DOS 7.1',
                      'Historical changelog', 'W95ICONS.DLL', 'CTL3DV2.DLL'):
            self.assertIn(value, text)
        self.assertNotIn('Calmira LFN Release 3.3', text)
        self.assertNotIn('uncheck the "Use 32-bit File Access"', text)
        self.assertNotIn("You will need Microsoft's protected mode help compiler", text)
        self.assertNotIn('try moving all the Calmira files into the Windows directory', text)
        self.assertNotIn('are intended for Delphi programmers', text)

    def test_missing_bitmap_fails_without_replacing_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source'
            shutil.copytree(ROOT / 'help', source)
            (source / 'banner.bmp').unlink()
            output = Path(directory) / 'output.hlp'
            output.write_bytes(b'previous build')
            with self.assertRaisesRegex(ValueError, 'banner.bmp not found'):
                HELP.build(output, source)
            self.assertEqual(output.read_bytes(), b'previous build')

    def test_build_refuses_to_replace_maintained_binary(self):
        with self.assertRaisesRegex(ValueError, 'separate'):
            HELP.build(ROOT / 'help/calmira.hlp')

    def test_orphan_topic_fails_build_without_replacing_previous_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source'
            source.mkdir()
            (source / 'calmira.hpj').write_text(
                '[OPTIONS]\nCONTENTS=Contents\n[FILES]\ncalmira0.rtf\n'
                '[MAP]\nContents 1\nOrphan 2\n')
            (source / 'calmira.rtf').write_text(
                r'{\rtf1\ansi #{\footnote Contents}${\footnote Contents}'
                r'K{\footnote contents}\pard Contents\par'
                r'\page #{\footnote Orphan}${\footnote Orphan}'
                r'K{\footnote orphan}\pard A mapped but unlinked topic.\par}')
            output = Path(directory) / 'previous.hlp'
            output.write_bytes(b'previous build')
            output.with_suffix('.json').write_text('previous report')
            with self.assertRaisesRegex(ValueError, 'unreachable from Contents'):
                HELP.build(output, source)
            self.assertEqual(output.read_bytes(), b'previous build')
            self.assertEqual(output.with_suffix('.json').read_text(), 'previous report')


if __name__ == '__main__':
    unittest.main()
