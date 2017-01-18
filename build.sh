#!/bin/bash -e

WORK_DIR=$(dirname $0)
LSM_FILE=$WORK_DIR/join2domain.lsm

OLD_VERSION=$(egrep ^Version: $LSM_FILE)
NEW_VERSION=$(echo $OLD_VERSION | awk '{
    split($2,varr,".")
    print varr[1]"."varr[2]"."varr[3]+1
}')

sed -i "/^Version:/s/$OLD_VERSION/Version:        $NEW_VERSION/g" $LSM_FILE

if [ "$WORK_DIR" != "." ];then
    cd $WORK_DIR
fi
OLD_RUNS=$(ls *.run)
rm -f *.run

makeself --xz --complevel 9e --notemp --lsm ./join2domain.lsm \
join2domain/ join2domain-v$NEW_VERSION.run "join2domain files..." ./join2domain.sh

tar -czvf ../join2domain-v$NEW_VERSION.tar.gz join2domain-v$NEW_VERSION.run

git add *
git add $OLD_RUNS
git commit -m "Released join2domain v$NEW_VERSION...!"
git push origin master
git tag -a v$NEW_VERSION -m "v$NEW_VERSION"
git push origin v$NEW_VERSION
