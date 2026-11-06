-- Definition prefixes preserved while crossing their last historical pool version.
return {
  {
    through = 4,
    from = { 'src.content.creatures.buer', 'attacks' },
    to = { 'src.content.migrations.gardener_045', 'attacks' },
  },
  {
    through = 4,
    from = { 'src.content.enemies', 'buer', 'attacks' },
    to = { 'src.content.migrations.gardener_045', 'attacks' },
  },
  {
    through = 5,
    from = { 'src.content.creatures.furfur', 'attacks' },
    to = { 'src.content.migrations.furfur_045', 'attacks' },
  },
  {
    through = 5,
    from = { 'src.content.enemies', 'furfur', 'attacks' },
    to = { 'src.content.migrations.furfur_045', 'attacks' },
  },
}
