# 🐘 Contenedor Centralizado de PostgreSQL con Docker

Este repositorio contiene la configuración de un contenedor de **PostgreSQL** usando `docker-compose`, diseñado para ser reutilizado de forma **independiente** por diferentes proyectos backend como **Spring Boot 3**, **Node.js**, entre otros.

---

## 🚀 Características

- PostgreSQL 16 en contenedor
- Exposición del puerto `5432`
- Red privada `pg-net` para conectar proyectos por red
- Volumen persistente para datos
- Soporte para múltiples bases de datos
- Scripts de inicialización automática opcionales

---

## 📦 Requisitos

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

---

## 🛠️ Estructura del proyecto

```bash
.
├── docker-compose.yml
├── init/
│   └── init.sql           # (opcional) scripts SQL para crear BD y usuarios
├── .gitignore
└── README.md
