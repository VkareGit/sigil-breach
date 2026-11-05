-- Definition prefixes preserved when a pool save crosses version 4.
return {
  {
    from = { 'src.content.creatures.buer', 'attacks' },
    to = { 'src.content.migrations.gardener_045', 'attacks' },
  },
  {
    from = { 'src.content.enemies', 'buer', 'attacks' },
    to = { 'src.content.migrations.gardener_045', 'attacks' },
  },
}
