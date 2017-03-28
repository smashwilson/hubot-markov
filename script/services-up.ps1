docker run -d -p 6379:6379 --name redis redis
docker run -d -p 5432:5432 -u postgres -e POSTGRES_USER=markov -e POSTGRES_PASSWORD=shhh --name postgres postgres:9.6

$env:REDIS_URL = "redis://localhost:6379"
$env:DATABASE_URL = "postgres://markov:shhh@localhost/markov"
$env:DATABASE_SSL = "false"

Write-Output "Services up"
