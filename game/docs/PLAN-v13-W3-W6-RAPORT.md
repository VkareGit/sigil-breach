# Plan v13, etapy W3-W6: raport

**W3, warsztat.** Na poligonie: F3 następny cios wybranego stwora, F4 cios teraz, F5
ponowne wczytanie plików stworów bez restartu, F6 czas 1, 1/2, 1/4 i stop, F7 krok.
Podgląd hitboxów rysuje tor `sweep` i `seize` oraz kierunek ciała w windupie: złoty, gdy
może się jeszcze obrócić, czerwony po blokadzie. Czas należy do aplikacji, symulacja
dalej idzie całymi krokami. Opis w `ROZSZERZANIE.txt`.

**W4, równowaga.** `steady` na ciosie: gardę złamaną w ciosie ciało traci po nim.
`steadfast` na ciele: trafienia go nie wstrzymują. `breakTime`: złamanie wyrzuca z ciosu.
`execution`: [E] z bliska zabiera udział życia, zeruje pasek i zamyka okno.

**W5, wysiłek.** Polityka trybu `attrition`: salwa i unik płacą wytrzymałością, unik
trwa dłużej, ręce są zajęte, flaska pod F, brak leczenia z zabójstw. Zapas może zejść
poniżej zera. Stare zasady można przywrócić opcją sesji `attrition = false` i tak robi
zamrożona referencja 0.33.

**W6, myślenie.** `answers`: reakcje na picie, przeładowanie, strzał z daleka, plecy
i przyklejenie. Wybór ciosu ważonym losowaniem z ziarna sesji. Styl `duel` między
ciosami. `personal`: duże ciało trzyma pokój, ekran nie tonie w pikselach.

Odstępstwo: bramka liczy ciosy na sekundę tylko w czasie, gdy ciało stoi wolne. Złamana
garda jest zarobiona i nie obniża wyniku. Testy starych fal i areny działają na starych
stworach, bo znikają w O4.

Atrybucja hashy: stary `boss.lua` i `attrition = false` odtwarzają 6 z 6 poprzednich
wartości oraz wszystkie referencje 0.33.

Wynik: stoi i strzela ginie po 14,8 s, bossowi zostaje 62%. Ale bot z jednym odruchem
wciąż wygrywa, więc to jeszcze nie jest cel. Dalej: karta ciosów w `PLAN-SOULS-v13.md`.
