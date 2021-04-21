nohup npm run build > build.log 2>&1 &
nohup http-server ./dist -c-1 -p 6789 > http-server.log 2>&1 &
./aoi_server.sh
