.PHONY : amex
.RECIPEPREFIX = -
amex:
-	./amex2cvs.rb test/real_data/amex/2021-01-11.txt
