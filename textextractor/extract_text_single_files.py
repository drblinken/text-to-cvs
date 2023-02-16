import glob
import sys
import os
from pypdf import PdfReader
import re

if len(sys.argv) < 2:
    print("usage: %s <dirname>", argv[0])
    print("extracts all *.pdf in this dir to *.txt in same dir")
    exit(1)

# takes all pdf in dir and creates a text file for each of them.
dir_name = sys.argv[1]

# creates an absolute path, fix
# glob_pattern = os.path.join('.', dir_name, '/*.pdf')
glob_pattern = dir_name+'/*.pdf'

# step 1:glob
# print(glob_pattern)
filenames = glob.glob(glob_pattern)
# print(filenames)


# step 2: extract text with pypdf

extre = re.compile(r"\.pdf$", re.IGNORECASE)


for filename in filenames:
    reader = PdfReader(filename)

    number_of_pages = len(reader.pages)
    print(filename)
    txt_filename = extre.sub(".txt", filename)
    print(txt_filename)
    f = open(txt_filename, "w")
    for page in reader.pages:
        text = page.extract_text()
        f.write(text)
    f.close()
