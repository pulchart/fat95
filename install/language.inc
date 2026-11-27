; fat95 language: default from @language, P_LANGUAGE writes it into L:fat95
(set fat95-lang-dflt
  (if (= @language "czech") 1
  (if (= @language "deutsch") 2
  (if (patmatch "espa?ol" @language) 3
  (if (patmatch "fran?ais" @language) 4
  (if (= @language "greek") 5
  (if (= @language "magyar") 6
  (if (= @language "polski") 7
  (if (= @language "russian") 8
  (if (patmatch "t?rk?e" @language) 9 0))))))))))
(procedure P_LANGUAGE
  (set fat95-lang
    (select
      (askchoice
        (prompt "Language of fat95 requesters")
        (help "Writes the texts and code page of the chosen language into L:fat95.")
        (choices "English" "Cestina" "Deutsch" "Espanol" "Francais" "Greek"
          "Magyar" "Polski" "Russian" "Turkce")
        (default fat95-lang-dflt))
      "english" "cestina" "deutsch" "espanol" "francais" "greek" "magyar"
      "polski" "russian" "turkce"))
  (working "Setting the language of L:fat95")
  (if (<> 0 (run (cat "l/install95 w locale/" fat95-lang)))
    (abort "install95 could not set the language of L:fat95.")))
