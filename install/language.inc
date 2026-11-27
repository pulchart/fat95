; fat95 language: default from @language, P_LANGUAGE writes it into L:fat95
(set fat95-lang-dflt
  (if (= @language "czech") 1
  (if (= @language "dansk") 2
  (if (= @language "deutsch") 3
  (if (patmatch "espa?ol" @language) 4
  (if (patmatch "fran?ais" @language) 5
  (if (= @language "greek") 6
  (if (= @language "italiano") 7
  (if (= @language "magyar") 8
  (if (= @language "nederlands") 9
  (if (= @language "norsk") 10
  (if (= @language "polski") 11
  (if (patmatch "portugu?s" @language) 12
  (if (= @language "russian") 13
  (if (= @language "svenska") 14
  (if (patmatch "t?rk?e" @language) 15 0))))))))))))))))
(procedure P_LANGUAGE
  (set fat95-lang
    (select
      (askchoice
        (prompt "Language of fat95 requesters")
        (help "Writes the texts and code page of the chosen language into L:fat95.")
        (choices "English" "Cestina" "Dansk" "Deutsch" "Espanol" "Francais"
          "Greek" "Italiano" "Magyar" "Nederlands" "Norsk" "Polski"
          "Portugues" "Russian" "Svenska" "Turkce")
        (default fat95-lang-dflt))
      "english" "cestina" "dansk" "deutsch" "espanol" "francais" "greek"
      "italiano" "magyar" "nederlands" "norsk" "polski" "portugues" "russian"
      "svenska" "turkce"))
  (working "Setting the language of L:fat95")
  (if (<> 0 (run (cat "l/install95 w locale/" fat95-lang)))
    (abort "install95 could not set the language of L:fat95.")))
