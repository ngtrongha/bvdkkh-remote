# Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
# Project: BVĐKKH - Remote
# Author: Nguyễn Trọng Hà
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ReleaseNotesTest(unittest.TestCase):
    def test_build_range_and_bounded_fallback(self):
        script = Path(__file__).with_name('generate-release-notes.sh').resolve().as_posix()
        bash = (r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt'
                else shutil.which('bash'))
        with tempfile.TemporaryDirectory(prefix='release-notes-test-') as directory:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=directory, text=True).strip()

            git('init', '-q')
            git('config', 'user.name', 'Test')
            git('config', 'user.email', 'test@example.invalid')
            for index in range(35):
                git('commit', '-q', '--allow-empty', '-m', f'fix: old change {index}')
            base = git('rev-parse', 'HEAD')
            git('commit', '-q', '--allow-empty', '-m', 'fix: hide Job console')

            def notes(base_sha):
                subprocess.run([bash, script, 'v1.5.18', base_sha],
                               cwd=directory, check=True)
                return Path(directory, 'release_notes.md').read_text(encoding='utf-8')

            current = notes(base)
            self.assertIn('hide Job console', current)
            self.assertNotIn('old change', current)
            rebuilt = notes(git('rev-parse', 'HEAD'))
            self.assertNotIn('old change', rebuilt)
            self.assertNotIn('* fix:', rebuilt)
            fallback = notes('missing-base')
            self.assertEqual(sum(line.startswith('* ') for line in fallback.splitlines()), 30)
            self.assertNotIn('old change 0 (', fallback)


if __name__ == '__main__':
    unittest.main()
