import unittest
from category_classifier import classify

class CategoryTests(unittest.TestCase):
    def test_action_beats_documentation_heading(self):
        self.assertEqual(classify('Open command menu (Keyboard shortcuts)'), 'Ricerca')
        self.assertEqual(classify('Toggle sidebar (Editing)'), 'Vista')

    def test_word_boundaries(self):
        self.assertEqual(classify('Shortcut unrelated to editing'), 'Altri comandi')
        self.assertEqual(classify('Close current tab'), 'Finestre e schede')
        self.assertEqual(classify('Move to next table cell'), 'Tabelle e celle')

    def test_action_precedes_object(self):
        self.assertEqual(classify('Copy conversation path'), 'Scrittura e modifica')
        self.assertEqual(classify('New chat'), 'Chat e messaggi')

    def test_native_and_editor_commands(self):
        self.assertEqual(classify('Apri cartella'), 'File')
        self.assertEqual(classify('Seleziona tutto'), 'Selezione')
        self.assertEqual(classify('editor.action.toggleSidebar'), 'Vista')

if __name__ == '__main__':
    unittest.main()
