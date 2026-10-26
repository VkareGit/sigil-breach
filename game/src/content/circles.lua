-- Only the first circle is playable. The others are an honest campaign map.
-- name, roman, law: text keys (content/text.lua).
return {
  {
    name = 'circle_limbo',
    roman = 'roman_1',
    available = true,
    law = 'circle_limbo_law',
    waves = 4,
  },
  { name = 'circle_lust', roman = 'roman_2', available = false },
  { name = 'circle_gluttony', roman = 'roman_3', available = false },
  { name = 'circle_greed', roman = 'roman_4', available = false },
  { name = 'circle_wrath', roman = 'roman_5', available = false },
  { name = 'circle_heresy', roman = 'roman_6', available = false },
  { name = 'circle_violence', roman = 'roman_7', available = false },
  { name = 'circle_fraud', roman = 'roman_8', available = false },
  { name = 'circle_treachery', roman = 'roman_9', available = false },
}
