---
name: prova-robson-lab
description: The prova-robson project — IFSP DevOps lab (gateway+Ansible+Docker+load balancer) and its fixed conventions
metadata: 
  node_type: memory
  type: project
  originSessionId: b3ece8f5-94db-419a-bc4d-b8818e238b5f
---

Prova prática do Prof. Robson Lopes (IFSP Guarulhos), pasta `~/Documents/prova-robson`. Reproduz os Labs 00–06 dele + um load balancer.

- **DECISÃO 2026-07-06: a solução OFICIAL da prova é a `devops-workstation/` (TechCorp), NÃO a da raiz.** A aluna confirmou. A da raiz (nginx+LB, `GUIA.md`/`bootstrap.sh`) fica como fallback validado. A `devops-workstation/` é mais elaborada: 5 VMs (add **homologacao `.150`**, app Node+MySQL), 2 cenários Ansible (Cenário 1 = provisionar dev01/dev02 com Docker/JDK21/Maven/VS Code/chave-GitLab; Cenário 2 = deploy na homologacao), tem `.git` próprio. **AINDA NÃO validada nas VMs.**
- **Riscos conhecidos da devops-workstation (corrigir antes da prova — precisa funcionar):** (1) Cenário 1 instala Docker do repo **Ubuntu** (`download.docker.com/linux/ubuntu` + `ansible_distribution_release`) mas as VMs são **Debian 12** → 404 (a da raiz usa `docker.io`, funciona). (2) Cenário 2 faz `git clone` de `gitlab.techcorp.com.br` (**GitLab fictício, não existe**) → deploy quebra na task 2.2; o app real está em `devops-workstation/app-homologacao/`. (3) O bloco de homologacao do `COPIAR_E_COLAR.md` é auto-contido (express+nginx, sem MySQL) e diverge do Cenário 2 (MySQL+git). (4) `master-setup.sh` pressupõe SSH por chave host→VMs já pronto. (5) homologacao `.150` é uma 5ª VM que ainda não existe como clone.

- **Número da aluna X = 13** → rede LAN `192.168.13.0/24` (o `13` é fixo, diferencia a prova das dos outros alunos). NÃO trocar sem ela pedir.
- Topologia: **gateway** `.101` (NAT via `internet.sh` + LB nginx), **operacao** `.151` (control node Ansible), **dev01** `.201` e **dev02** `.202` (backends com container nginx). Grupo Ansible dos backends = `[instancias]`.
- Usuário padrão das VMs = **`sysadmin`** (`NOPASSWD: ALL`). App web = container **nginx** servindo página estilo Lab 05 (`{{ ansible_hostname }}`).
- Bases: OVAs `gateway00_v25.ova` (gateway) e `Operacao_v2025.ova` (base de operacao+dev01+dev02, via linked clones). Repo de referência do professor: github.com/flrobson77/servidores (branch master).
- **Rede: dois modos, mesma config interna.** Em casa o host está em **Wi-Fi** → usar **Rede Interna (intnet)** (bridge sobre Wi-Fi falha). A **máquina da prova é cabeada** → usar **Bridge** (`enp1s0`). O `setup-rede-host.sh` recebe `--rede intnet|bridge`; o guest não muda.
- Entregáveis: `bootstrap.sh` (universal, auto-contido, por papel), `setup-rede-host.sh` (VBoxManage no host), `ansible/` (roles docker/webapp/loadbalancer), `GUIA.md`. Plano completo em `~/.claude/plans/wise-wibbling-parnas.md`.
- **VALIDADO end-to-end em 2026-07-06** nas 4 VMs reais (intnet): ansible ok, containers nginx nos 2 backends, load balancer no gateway alternando dev01/dev02. Funciona.
- Operacional: usuários dos guests = **root** no gateway, **sysadmin** nas outras (base Operacao). O **gateway NÃO tem Guest Additions** → montar a pasta compartilhada com `modprobe vboxsf && mount -t vboxsf prova /mnt/prova` (módulo já vem no kernel Debian 12); operacao/dev01/dev02 têm GA 7.0.12 (pasta em `/media/sf_prova`, dá pra dirigir via `VBoxManage guestcontrol`).
- Base clonada = VM `Operacao_v2025` (linked clones operacao/dev01/dev02). VMs `gateway`+`Operacao_v2025` ficam; disco do host é apertado (~20 GB livres após limpeza).

Ver [[align-with-professor-materials]].
