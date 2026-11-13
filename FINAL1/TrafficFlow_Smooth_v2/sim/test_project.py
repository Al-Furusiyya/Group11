"""Source/interface consistency checks. These do NOT replace HDL compilation."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]


class ProjectTests(unittest.TestCase):
    def test_quartus_source_paths_exist(self):
        s=(ROOT/'integration/python_sources.qsf').read_text()
        files=re.search(r'foreach file_name \{([^}]+)\}',s).group(1).split()
        self.assertEqual(len(files),len(set(files)))
        for name in files:self.assertTrue((ROOT/name).is_file(),name)
        self.assertNotIn('sim/sld_virtual_jtag_model.v',files)
        self.assertIn('TOP_LEVEL_ENTITY demo_VGA_Python',(ROOT/'Lab4_Python_JTAG.qsf').read_text())

    def test_scene_ports_match_top_and_capture_bench(self):
        scene=re.sub(r'//[^\n]*','',(ROOT/'vga_scene.v').read_text())
        header=re.search(r'module vga_scene\s*\((.*?)\);',scene,re.S).group(1)
        ports={re.findall(r'\b\w+\b',token)[-1] for token in header.split(',')}
        for path,instance in [('demo_VGA_Python.v','scene'),('sim/tb_vga_capture.v','dut')]:
            text=(ROOT/path).read_text()
            body=re.search(r'vga_scene '+instance+r'\s*\((.*?)\);',text,re.S).group(1)
            connected=set(re.findall(r'\.(\w+)\s*\(',body))
            self.assertEqual(ports,connected,path)

    def test_pin_assignments_unique(self):
        pins=re.findall(r'set_location_assignment (PIN_\w+) -to (\S+)',(ROOT/'integration/de1_soc_pins.qsf').read_text())
        self.assertEqual(len(pins),46)
        self.assertEqual(len({p for p,_ in pins}),46)
        self.assertEqual(len({n for _,n in pins}),46)

    def test_firmware_reserved_io_space_and_size(self):
        words=(ROOT/'CPU/traffic_firmware.hex').read_text().split()
        self.assertEqual(len(words),1024)
        self.assertTrue(all(re.fullmatch('[0-9A-Fa-f]{4}',w) for w in words))
        self.assertTrue(all(int(w,16)==0 for w in words[0x3c0:]))

    def test_reference_states_are_valid_width(self):
        frames=(ROOT/'sim/vga_states.hex').read_text().split()
        self.assertEqual(len(frames),6)
        self.assertTrue(all(re.fullmatch('[0-9a-f]{62}',f) for f in frames))
        cars=(ROOT/'sim/vga_cars.hex').read_text().split()
        self.assertEqual(len(cars),6)
        self.assertTrue(all(re.fullmatch('[0-9a-f]{200}',f) for f in cars))


if __name__=='__main__':unittest.main()
