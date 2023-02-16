#textextractor

# be careful to update the version of pypdf,
# as the scripts rely on the more or less exact text exported-
# and the pypdf documentation says that the order may change:

ok banken/gls/2020 ++ cat one_text.txt| wc -l
     313
ok banken/gls/2020 ++ cat text.txt | wc -l
    3091



- text der pdfs mit pypdf extrahieren

# steps taken
        pipenv install pypdf
# usage

    pipenv shell


1. glob
https://docs.python.org/3/library/glob.html

hier wird glob/expansion von zsh ausgeführt!
python3 extract_text.py pdfs/*.pdf
-> braucht "" -vlt lieber nur dirname übergeben weils eh nur pdf kann?

https://www.geeksforgeeks.org/python-os-path-join-method/

python3 extract_text.py "pdfs/*.pdf"

2.  step 2: extract text with pypdf

https://pypdf.readthedocs.io/en/stable/index.html
https://pypdf.readthedocs.io/en/stable/user/extract-text.html

oder noch einfacher als bsp auf der readme:
https://github.com/py-pdf/pypdf

from pypdf import PdfReader

reader = PdfReader("example.pdf")
number_of_pages = len(reader.pages)
page = reader.pages[0]
text = page.extract_text()



# error: pypdf.errors.DependencyError: PyCryptodome is required for AES algorithm
https://stackoverflow.com/questions/73701005/pypdf2-error-pycryptodome-is-required-for-aes-algorithm

pipenv install pycryptodome



# step 3: improve by implementing parameter to either write in a file or
provide output file (not necessary on *nix as can be done with cmd > filename)
sys.stdout
is a file stream that can be used like any file output stream, see:
https://www.geeksforgeeks.org/sys-stdout-write-in-python/
https://www.w3schools.com/python/ref_file_write.asp
