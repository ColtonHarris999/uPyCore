"""Protocol tests: reject incomplete or non-partitioning cycle attribution."""
import tempfile
import contextlib
import io
import unittest
from pathlib import Path
import runtime_profile as p

class ProfileProtocol(unittest.TestCase):
    def parse(self,text):
        with tempfile.TemporaryDirectory() as d:
            f=Path(d)/'raw';f.write_text(text)
            return p.parse_profile(f,{'1':'example:work'},['S_FETCH'])
    def fixture(self):
        return ('META 10 14 4 2 0\nFUNCTION 1 4 4 1\nGROUP 0 4\n'
                'REASON 0 4\nCROSS 0 0 4\nSTATE 0 4\nPC 10 1\n')
    def test_valid_partition(self):
        r=self.parse(self.fixture());self.assertEqual(r['cycles'],4)
        self.assertEqual(r['functions']['example:work']['inclusive_cycles'],4)
    def test_reject_double_count(self):
        with self.assertRaises(ValueError):self.parse(self.fixture().replace('GROUP 0 4','GROUP 0 5'))
    def test_reject_missing_timer(self):
        with self.assertRaises(ValueError):self.parse(self.fixture().replace('4 2 0','4 1 0'))
    def test_reject_unknown_ancestry(self):
        with self.assertRaises(ValueError):self.parse(self.fixture().replace('4 2 0','4 2 1'))
    def test_kernel_harness_executes_reference_without_collisions(self):
        for name,expected in [('misc_aes','RESULT (32, True)'),('bm_fannkuch','RESULT (6, 10)')]:
            ticks=iter([100,200]);ns={'bench_ticks':lambda:next(ticks)};out=io.StringIO()
            with contextlib.redirect_stdout(out):exec(p.kernel_source(name),ns)
            self.assertEqual(out.getvalue().splitlines(),['CYCLES 100',expected])
    def test_state_table_is_unambiguous(self):
        states=p.state_names();self.assertEqual(len(states),len(set(states)))
        self.assertLess(len(states),2048)

if __name__=='__main__':unittest.main()
