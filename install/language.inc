; fat95 language: default from @language, P_LANGUAGE writes it into L:fat95;
; install95 fits fat95 @FAT95_VERSION@, another L:fat95 version asks first
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
(procedure P_LANGUAGE_SET
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
  (set fat95-rc (run (cat "l/install95 >ENV:fat95inst w locale/" fat95-lang)))
  (set fat95-err (getenv "fat95inst"))
  (if (exists "ENV:fat95inst") (delete "ENV:fat95inst"))
  (if (<> 0 fat95-rc)
    (abort (cat "install95 could not set the language of L:fat95:\n" fat95-err))))
(procedure P_LANGUAGE
  (set fat95-have (getversion "L:fat95"))
  (set fat95-go 1)
  (if (<> fat95-have (+ (* @FAT95_MAJOR@ 65536) @FAT95_MINOR@))
    (set fat95-go
      (askbool
        (prompt (cat "L:fat95 is version " (/ fat95-have 65536) "."
                     (- fat95-have (* (/ fat95-have 65536) 65536))
                     ", the language files here are for fat95 @FAT95_VERSION@. "
                     "Set the language anyway?"))
        (help @askbool-help)
        (default 0))))
  (if fat95-go (P_LANGUAGE_SET)))
