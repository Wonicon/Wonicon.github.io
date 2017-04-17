cd _site
cp ../CNAME .
cp -r ../../nju-oslab-lecture/_site oslab
git init
git add -A
git commit -m 'Publish'
git remote add origin git@github.com:Wonicon/Wonicon.github.io.git
git push -fu origin master
