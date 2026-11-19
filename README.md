# Avaliação Prática de DevOps — Prova C: Cadastro de Cursos

Sistema para cadastrar cursos e consultar o catálogo. A aplicação roda em duas VMs: a infraestrutura é criada com OpenTofu, preparada com cloud-init e configurada com Ansible, e todos os serviços rodam em contêineres Docker.

**Repositório:** https://github.com/JoaoToledo18/avaliacao_pratica_Devops2026

## Integrantes do grupo

| Nome completo | RA |
|---------------|----|
| Grazielly Zambello Fuzato | 26001894 |
| João Vitor Toledo da Silva | 24000550 |
| Pedro de Freitas da Silva | 24000809 |

## Tecnologias

OpenTofu • cloud-init • Ansible • Docker • Node.js (Express) • MySQL 8 • Nginx

## Arquitetura

```
        VM1 - aplicação web                         VM2 - API e banco
 ┌───────────────────────────────┐          ┌───────────────────────────────┐
 │ Docker: Nginx + HTML (:80)    │  — HTTP →│ Docker: API Node.js (:3000)   │
 │ Formulário + link             │          │ Docker: MySQL (rede interna)  │
 │ "Listar todos os cursos"      │          │ Rotas POST/GET + persistência │
 └───────────────────────────────┘          └───────────────────────────────┘
 OpenTofu provisiona as VMs | cloud-init prepara o Docker | Ansible implanta os serviços
```

- **VM1:** página HTML servida por um contêiner Nginx. O formulário e a listagem chamam a API da VM2 por requisições HTTP (`fetch`).
- **VM2:** API REST em Node.js e banco MySQL, em contêineres na mesma rede do Docker Compose. Os dados ficam no volume `dados_mysql`.

### Dados do curso

| Campo | Tipo |
|-------|------|
| Nome do curso (`nome`) | Texto |
| Instrutor responsável (`instrutor`) | Texto |
| Preço (`preco`) | Decimal |
| Quantidade de vagas (`vagas`) | Inteiro |

### Rotas da API REST

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/curso` | Recebe os quatro campos e cadastra um curso no MySQL |
| GET | `/cursos` | Retorna todos os cursos cadastrados em JSON |

### CORS

A API usa o middleware `cors`. Ela permite apenas a origem da aplicação web (`http://<IP_VM1>`) e os métodos `GET`, `POST` e `OPTIONS` (preflight). O Ansible define essa origem automaticamente na variável `WEB_ORIGIN`.

## Estrutura do repositório

```
├── ansible/
│   ├── inventory          # IPs das VMs (grupos web e api)
│   └── playbook.yml       # configura as VMs e implanta os contêineres
├── iac/
│   ├── cloud_init.cfg     # usuário, chave SSH e instalação do Docker
│   └── main.tf            # cria a VM1 e a VM2 (libvirt)
├── app/
│   ├── Dockerfile         # imagem Nginx com o HTML
│   ├── index.html         # formulário + listagem
│   └── config.js          # URL da API (gerado pelo Ansible)
├── api/
│   ├── Dockerfile         # imagem da API Node.js
│   ├── docker-compose.yml # API + MySQL
│   ├── index.js           # rotas POST /curso e GET /cursos
│   ├── package.json
│   └── init.sql           # criação da tabela cursos
└── README.md
```

## Instruções de execução

### Pré-requisitos (máquina host)

- KVM/libvirt com a rede `default` ativa
- OpenTofu
- Ansible
- Chave SSH do laboratório:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops_lab -N ""
```

### 1. Provisionar as VMs (OpenTofu + cloud-init)

```bash
cd iac
tofu init
tofu apply
```

No final, a saída `ips` mostra o IP de cada VM. Por exemplo:

```
ips = {
  "vm1" = "192.168.122.71"
  "vm2" = "192.168.122.10"
}
```

### 2. Atualizar o inventário

Coloque os IPs obtidos no arquivo `ansible/inventory`:

```ini
[web]
vm1 ansible_host=<IP_VM1>

[api]
vm2 ansible_host=<IP_VM2>
```

### 3. Implantar os serviços (Ansible + Docker)

```bash
cd ../ansible
ansible-playbook -i inventory playbook.yml
```

O playbook:

1. espera o cloud-init terminar e confirma que o Docker está ativo;
2. na **VM2**, copia a pasta `api/` e roda `docker compose up -d --build` (API + MySQL);
3. na **VM1**, copia a pasta `app/`, gera o `config.js` com o IP da VM2, monta a imagem e sobe o contêiner Nginx na porta 80.

## Endereço de acesso

| Serviço | Endereço |
|---------|----------|
| Aplicação web (VM1) | `http://<IP_VM1>` (ex.: http://192.168.122.71) |
| API, listagem (VM2) | `http://<IP_VM2>:3000/cursos` (ex.: http://192.168.122.10:3000/cursos) |

Pelo navegador, acesse a VM1, preencha o formulário e clique em **Cadastrar**. Depois, clique em **Listar todos os cursos** para ver os registros gravados no MySQL da VM2.

### Teste pela linha de comando

```bash
curl -X POST http://<IP_VM2>:3000/curso \
  -H "Content-Type: application/json" \
  -d '{"nome":"DevOps","instrutor":"Maria","preco":199.90,"vagas":30}'

curl http://<192.168.122.122>:3000/cursos
```

Para conferir os dados direto no banco (na VM2):

```bash
cd /opt/api && sudo docker compose exec mysql mysql -uapp -papp123 cursos -e "SELECT * FROM cursos;"
```
