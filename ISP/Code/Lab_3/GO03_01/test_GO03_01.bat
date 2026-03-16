@echo off
set URL=http://localhost:3000

echo --- Testing GO03_01 ---

echo [1] GET /A
curl -X GET %URL%/A
echo.

echo [2] GET /A/B
curl -X GET %URL%/A/B
echo.

echo [3] POST /A
curl -X POST %URL%/A
echo.

echo [4] POST /A/B
curl -X POST %URL%/A/B
echo.

echo [5] PUT /A
curl -X PUT %URL%/A
echo.

echo [6] PUT /A/B
curl -X PUT %URL%/A/B
echo.

echo [7] GET / (not mentioned)
curl -X GET %URL%/unknown
echo.

echo [8] POST /unknown (not mentioned)
curl -X POST %URL%/test/route
echo.

echo [9] PUT /data (not mentioned)
curl -X PUT %URL%/data
echo.

echo --- Testing Complete ---
pause