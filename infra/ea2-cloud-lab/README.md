# EA2 · Laboratorio Cloud: Infraestructura y Despliegue (K3s + NLB + RDS)

Este documento detalla la arquitectura de infraestructura diseñada para el **Examen Transversal (EA2)** del curso **Ciclo de Vida del Software II (AUY1104)**. El objetivo es proporcionar un entorno de nube resiliente y escalable en AWS utilizando **Terraform** para el aprovisionamiento y **GitHub Actions** para la automatización (CI/CD).

---

## 🏗️ Arquitectura de Referencia

El laboratorio implementa una arquitectura de red segmentada en AWS, diseñada para alta disponibilidad y seguridad:

### 1. Red y Conectividad (VPC)
*   **VPC Segmentada:** Direccionamiento `10.X.0.0/16` (donde `X` es configurable).
*   **Subredes Públicas (Tier 1):** Alojan el balanceador de carga (NLB) y las instancias de cómputo para permitir acceso administrativo y de tráfico.
*   **Subredes Privadas (Tier 2):** Alojan la base de datos RDS MySQL, aislada del tráfico directo de Internet.
*   **Internet Gateway:** Permite la salida a Internet para actualizaciones y acceso entrante vía NLB.

### 2. Capa de Cómputo y Orquestación (K3s)
*   **2 Instancias EC2 (Ubuntu 22.04):** Ubicadas en distintas subredes públicas para redundancia.
*   **K3s (Lightweight Kubernetes):** Instalación automática de un stack de Kubernetes optimizado para entornos de laboratorio y desarrollo rápido.
*   **Almacenamiento:** Volúmenes EBS de 30GB (gp2) para soportar el runtime de contenedores.

### 3. Base de Datos (RDS MySQL)
*   **Arquitectura Master-Replica:**
    *   **Instancia Primaria:** Gestiona operaciones de escritura/lectura.
    *   **Réplica de Lectura:** Permite escalar las consultas y ofrece una base para redundancia de datos.
*   **Motor:** MySQL 8.0 sobre instancias de clase `db.t3.micro`.

### 4. Balanceo de Carga (NLB TCP)
*   **Network Load Balancer:** Utilizado para manejar tráfico TCP masivo con baja latencia.
*   **Mapeo de NodePorts:** El NLB reenvía el tráfico desde puertos públicos hacia los `NodePorts` de Kubernetes (rango 30080-30100).
*   **Acceso a Aplicaciones:**
    *   **API:** Acceso balanceado hacia los contenedores de la aplicación.
    *   **Grafana:** Acceso directo al dashboard de monitoreo vía puerto 30200.

### 5. Registro de imágenes (Docker Hub)
*   **Docker Hub:** La API se construye en CI y se publica con la cuenta del alumno (`DOCKER_USERNAME` / `DOCKER_PASSWORD` en GitHub Secrets). Compatible con cuentas tipo AWS Academy sin permiso `ecr:CreateRepository`.

---

## 🛠️ Tecnologías Utilizadas

| Componente | Herramienta |
| :--- | :--- |
| **Infraestructura como Código** | Terraform v1.9+ |
| **Plataforma Cloud** | AWS (Amazon Web Services) |
| **Orquestador** | K3s (Kubernetes) |
| **Automatización** | GitHub Actions |
| **Contenedores** | Docker |
| **Monitoreo** | Grafana |

---

## 🚀 Proceso de Despliegue (CI/CD)

### Estado de Terraform en S3 (obligatorio en CI)

El workflow usa **backend remoto S3** (`ea2-cloud-lab/<org>-<repo>/terraform.tfstate` en el bucket de la variable `EA2_S3_BUCKET`). Así la **segunda ejecución** reutiliza el state: `apply` solo crea o cambia lo necesario, no vuelve a levantar toda la VPC desde cero en cada run.

- **IAM:** `s3:GetObject`, `PutObject`, `DeleteObject` y `ListBucket` sobre ese prefijo.
- **Sin lock DynamoDB** (compatibilidad con cuentas restringidas): no dispares dos workflows al mismo tiempo contra el mismo state.
- **Purge script / borrado manual en AWS** sin `terraform destroy`: el `.tfstate` en S3 puede quedar desalineado. Borra el objeto `terraform.tfstate` en S3 o usa `terraform state` / `destroy` acorde; si no, el próximo `apply` puede fallar o recrear de forma incoherente.

El pipeline `infra2-ea2-provision-cloud-lab.yaml` automatiza todo el ciclo de vida:

1.  **Init + Plan & Apply (Terraform):** `terraform init` con backend S3, luego crea o actualiza red, servidores y base de datos según el state.
2.  **Instalación K8s:** Ejecuta scripts remotos vía SSH para configurar K3s en ambas máquinas virtuales.
3.  **Build & Push (API):** Construye la imagen de la API y la sube a Docker Hub (`<usuario>/ea2-cloud-lab-api:latest`).
4.  **K8s Configuration:** Crea los `Secrets` necesarios (credenciales RDS y pull secret de Docker Hub).
5.  **Workload Deployment:** Despliega la API y Grafana sobre el clúster.

---

## 📋 Salidas Principales (Outputs)

Al finalizar el despliegue, la infraestructura entrega los siguientes puntos de acceso:

*   **NLB DNS:** La URL pública para acceder a los servicios.
*   **RDS Primary/Replica Endpoints:** Direcciones internas para la base de datos.
*   **Imagen API:** Referencia Docker Hub publicada por el pipeline.
*   **VM Public IPs:** Direcciones para acceso administrativo vía SSH.
*   **State S3:** URI `s3://<bucket>/ea2-cloud-lab/<repo>/terraform.tfstate` (misma que muestra el resumen del job).

---

> **Nota:** Este entorno está diseñado para fines académicos y debe ser destruido utilizando el workflow `ea2-aws-lab-purge.yaml` para evitar costos innecesarios en AWS una vez finalizada la sesión de laboratorio.
