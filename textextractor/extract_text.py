import glob
import sys
import os
from pypdf import PdfReader

dir_name = sys.argv[1]

# creates an absolute path, fix
# glob_pattern = os.path.join('.', dir_name, '/*.pdf')
glob_pattern = dir_name+'/*.pdf'

# step 1:glob
print(glob_pattern)
filenames = glob.glob(glob_pattern)
print(filenames)


# step 2: extract text with pypdf


for filename in filenames:
    reader = PdfReader(filename)

    number_of_pages = len(reader.pages)
    for page in reader.pages:
        text = page.extract_text()
        print(text)
