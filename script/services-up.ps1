docker run -d -p 6379:6379 -e POSTGRES_USER=markov -e POSTGRES_PASSWORD=shhh --name redis redis
docker run -d -p 5432:5432 --name postgres postgres:9.6

$env:REDIS_URL = "redis://localhost:6379"
$env:DATABASE_URL = "postgres://markov:shhh@localhost/markov"

Write-Output "Services up"
