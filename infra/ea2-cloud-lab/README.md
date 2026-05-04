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

### 5. Registro de Imágenes (ECR)
*   **Amazon ECR:** Repositorio privado para el almacenamiento de imágenes Docker de la API, integrado con escaneo de vulnerabilidades al subir cambios.

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

El pipeline `infra2-ea2-provision-cloud-lab.yaml` automatiza todo el ciclo de vida:

1.  **Plan & Apply (Terraform):** Crea la red, servidores y base de datos.
2.  **Instalación K8s:** Ejecuta scripts remotos vía SSH para configurar K3s en ambas máquinas virtuales.
3.  **Build & Push (API):** Construye la imagen de la API y la sube al repositorio ECR.
4.  **K8s Configuration:** Crea los `Secrets` necesarios (credenciales de base de datos y llaves de acceso al ECR).
5.  **Workload Deployment:** Despliega la API y Grafana sobre el clúster.

---

## 📋 Salidas Principales (Outputs)

Al finalizar el despliegue, la infraestructura entrega los siguientes puntos de acceso:

*   **NLB DNS:** La URL pública para acceder a los servicios.
*   **RDS Primary/Replica Endpoints:** Direcciones internas para la base de datos.
*   **ECR Repository URL:** Dirección del repositorio de imágenes.
*   **VM Public IPs:** Direcciones para acceso administrativo vía SSH.

---

> **Nota:** Este entorno está diseñado para fines académicos y debe ser destruido utilizando el workflow `ea2-aws-lab-purge.yaml` para evitar costos innecesarios en AWS una vez finalizada la sesión de laboratorio.
