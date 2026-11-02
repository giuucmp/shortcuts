import unittest
from key_parser import parse
class ParserTests(unittest.TestCase):
 def test_symbols(self):self.assertEqual(parse('⌘ + ⇧ + P'),[{'key':'P','modifiers':9}])
 def test_compact_symbols(self):self.assertEqual(parse('⌃⌘F'),[{'key':'F','modifiers':5}])
 def test_italian_named_punctuation(self):self.assertEqual(parse('Maiuscole-Comando-Punto di domanda (?)'),[{'key':'?','modifiers':9}])
 def test_plus(self):self.assertEqual(parse('Command++'),[{'key':'+','modifiers':1}])
 def test_chord(self):self.assertEqual(len(parse('Ctrl+X Enter')),2)
 def test_notes_are_not_guessed(self):self.assertEqual(parse('Control+click on a file'),[])
 def test_fn(self):self.assertEqual(parse('Fn-Delete'),[{'key':'Delete','modifiers':16}])
unittest.main()
