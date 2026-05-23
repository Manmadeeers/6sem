# 6th Semester Labs

A structured repository for my 6th semester university labs, notes, and reports across multiple courses.

## Overview

This repository is organized by course.  
Most course folders follow a consistent structure:

- `Code` for lab implementations
- `Lections` for lecture materials
- `Texts` for supporting theory and references
- `Reports` where required by the course

## Repository Map

| Folder | Description |
|---|---|
| `CPSAP` | Course materials and labs (`Code`, `Lections`, `Texts`) |
| `IADB` | Course materials and labs (`Code`, `Lections`, `Texts`) |
| `IS` | Course materials and labs (`Code`, `Lections`, `Texts`) |
| `ISAS` | Course materials (`Lections`, `Reports`, `Texts`) |
| `ISP` | Programming labs and course materials (`Code`, `Lections`, `Texts`) |
| `ST` | Course materials (`Lections`, `Reports`, `Texts`) |
| `WADT` | Course materials and labs (`Code`, `Lections`, `Texts`) |

## ISP Labs Quick Navigation

Inside `ISP/Code`:

- `Lab_1` ... `Lab_11`
- API-focused labs include:
  - `Lab_5`: REST + PostgreSQL (`database/sql`)
  - `Lab_6`: REST + PostgreSQL + GORM
  - `Lab_10`: GraphQL + PostgreSQL + GORM
  - `Lab_11`: REST + PostgreSQL + OpenAPI UI (Swagger)

## Running Go Labs (Example)

```powershell
cd ISP/Code/Lab_11
go run GO11_01.go
```

For the OpenAPI-enabled lab:

- API base URL: `http://localhost:3000`
- Swagger UI: `http://localhost:3000/docs`
- OpenAPI JSON: `http://localhost:3000/openapi.json`

## PostgreSQL Notes (ISP API Labs)

Some ISP labs expect a local PostgreSQL setup with:

- user: `postgres`
- password: `pass`
- database: `celebrities_db`

Typical starter SQL:

```sql
CREATE DATABASE celebrities_db;

\c celebrities_db

CREATE TABLE IF NOT EXISTS Celebrities (
  Id INTEGER PRIMARY KEY,
  FullName TEXT NOT NULL,
  Nationality TEXT NOT NULL,
  ReqPhotoPath TEXT NOT NULL
);
```

## Goal

Keep all semester lab work in one place with clear structure, reproducible runs, and easy navigation between subjects.
