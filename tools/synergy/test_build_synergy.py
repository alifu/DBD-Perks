import math
import unittest

import build_synergy as b


class ExtractTagsTests(unittest.TestCase):
    def test_inflicting_a_status_is_production(self):
        produces, consumes, _ = b.extract_tags("X", "Hitting a Survivor inflicts Exposed for 30 seconds.")
        self.assertIn("Exposed", produces)
        self.assertNotIn("Exposed", consumes)

    def test_status_in_condition_is_consumption(self):
        produces, consumes, _ = b.extract_tags("Y", "Whenever a Survivor is Exposed, you gain 5% Haste.")
        self.assertIn("Exposed", consumes)
        self.assertIn("Haste", produces)

    def test_bullets_inherit_the_header_condition(self):
        produces, consumes, _ = b.extract_tags("Z", "While carrying a Survivor:\n• You gain 15% Haste.")
        self.assertIn("Haste", produces)

    def test_hex_perk_produces_hex(self):
        produces, _, _ = b.extract_tags("Hex: Ruin", "Generators are slowed.")
        self.assertIn("Hex", produces)

    def test_addon_lore_line_is_ignored(self):
        text = "Lore about Exposed things in the dark.\n\nIncreases speed by 10%."
        produces, consumes, _ = b.extract_tags("A", text)
        self.assertNotIn("Exposed", produces + consumes)

    def test_generator_pressure_theme(self):
        _, _, themes = b.extract_tags("G", "Kicking a Generator causes it to regress faster.")
        self.assertIn("Generator pressure", themes)


class AddonThemeTests(unittest.TestCase):
    def test_addons_get_stat_themes_but_perks_do_not(self):
        text = "Lore.\n\nIncreases the cooldown recovery and the range by 10%."
        _, _, addon_themes = b.extract_tags("A", text, is_addon=True)
        _, _, perk_themes = b.extract_tags("A", text)
        self.assertIn("Cooldown", addon_themes)
        self.assertIn("Range", addon_themes)
        self.assertNotIn("Cooldown", perk_themes)


class EmbeddingTests(unittest.TestCase):
    def test_vectors_are_unit_length_and_deterministic(self):
        docs = [b.tokenize(t) for t in ["fast generator regress kick", "generator regress block", "heal medkit survivor repair",
                                          "medkit heal faster", "totem hex cleanse", "hex totem curse"]]
        rows, size = b.tf_idf(docs)
        first, second = b.embed(rows, size, dimensions=3), b.embed(rows, size, dimensions=3)
        self.assertEqual(first, second)
        for vector in first:
            self.assertAlmostEqual(math.sqrt(sum(a * a for a in vector)), 1.0, places=1)

    def test_related_documents_are_closer_than_unrelated(self):
        docs = [b.tokenize(t) for t in ["generator regress kick damage", "generator regress damage block",
                                          "medkit heal healing faster", "healing medkit heal speed"]]
        rows, size = b.tf_idf(docs)
        v = b.embed(rows, size, dimensions=2)
        cos = lambda a, c: sum(x * y for x, y in zip(a, c))
        self.assertGreater(cos(v[0], v[1]), cos(v[0], v[2]))


if __name__ == "__main__":
    unittest.main()
