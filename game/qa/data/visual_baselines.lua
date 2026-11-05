-- Owner-approved visual references. A later filename is not an approval.
-- Do not replace a reference or add an accepted painting merely to pass QA.
-- New acceptances require the three visual reviews recorded in HISTORIA.
return {
  buer = {
    reference = 'assets/art/buer-fresco-v12.png',
    approved = {
      ['assets/art/buer-fresco-v12.png'] = {
        sha256 = 'b0c35650a0f57fea82414efe75779f9c09090758d868c5fa07148a0f96e3a59b',
        columns = 4,
        rows = 4,
      },
      ['assets/art/buer-idle-fresco-v13.png'] = {
        sha256 = 'a2cbc2356cec993fd631df085e9d4fc77d93d813203175cf124cd0a8455db575',
        columns = 2,
        rows = 2,
      },
    },
  },
  armored = {
    reference = 'assets/art/armored-fresco-v12.png',
    copies = {
      ['assets/art/armored-base-gutters-v45.png'] = { padding = 1 },
    },
    approved = {
      ['assets/art/armored-fresco-v12.png'] = {
        sha256 = 'f03d7c87527b2e5fd80208d9cdcf58f69493dd3e36701cd3353f6226dc5ba4a8',
        columns = 6,
        rows = 4,
      },
    },
  },
}
