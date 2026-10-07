; fat95 language: default from @language, P_LANGUAGE writes it into L:fat95
(set fat95-lang-dflt
  (if (= @language "deutsch") 1
  (if (patmatch "espa?ol" @language) 2
  (if (patmatch "fran?ais" @language) 3
  (if (= @language "magyar") 4
  (if (= @language "polski") 5
  (if (= @language "russian") 6 0)))))))
(procedure P_LANGUAGE
  (set fat95-lang
    (select
      (askchoice
        (prompt "Language of fat95 requesters")
        (help "Writes the texts and code page of the chosen language into L:fat95.")
        (choices "English" "Deutsch" "Espanol" "Francais" "Magyar" "Polski" "Russian")
        (default fat95-lang-dflt))
      "english" "deutsch" "espanol" "francais" "magyar" "polski" "russian"))
  (working "Setting the language of L:fat95")
  (if (<> 0 (run (cat "l/install95 w locale/" fat95-lang)))
    (abort "install95 could not set the language of L:fat95.")))
