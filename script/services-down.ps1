docker stop redis
docker stop postgres

docker rm redis
docker rm postgres

Write-Output "Services down"
