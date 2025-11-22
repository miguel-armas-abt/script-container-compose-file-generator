## ▶️ compose-file-generator

1. Configurar las [variables](./variables.env).
2. Configurar la lista de [proyectos](./projects.csv)
3. Ejecutar script

```shell
cd src
./main.sh
```

---

| variable                          | description                          |
|-----------------------------------|--------------------------------------|
| `.container.image.repository`     | Imagen                               |
| `.container.image.tag`            | Versión de imagen                    |
| `.container.port`                 | Puerto del contenedor                |
| `.container.variables.config-map` | Variables de configuración           |
| `.container.variables.secrets`    | Variables de configuración sensibles |
| `.container.compose.dependencies` | Dependencias del servicio            |
| `.container.compose.host-port`    | Puerto host                          |
| `.container.compose.volumes`      | Volumes                              |
