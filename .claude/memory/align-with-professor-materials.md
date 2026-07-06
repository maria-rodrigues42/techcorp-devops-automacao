---
name: align-with-professor-materials
description: "For prova-robson, align solutions to Prof. Robson's lab PDFs and prioritize reliability"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b3ece8f5-94db-419a-bc4d-b8818e238b5f
---

Nas tarefas da prova-robson, a aluna quer que a solução siga **exatamente o método do professor** e que **funcione perfeitamente** (confiabilidade acima de elegância).

**Why:** Ela pediu explicitamente "leia as aulas em pdf para refinar o plano conforme as aulas do meu professor" e "preciso que esse funcione perfeitamente". É uma prova avaliada — divergir do padrão do professor custa nota; algo que não funciona custa a prova.

**How to apply:** Antes de propor/implementar, leia os PDFs `Laboratorio_0X_*.pdf` na pasta do projeto e o repo github.com/flrobson77/servidores. Reaproveite as convenções dele (IPs, usuário `sysadmin`, `internet.sh`, ansible.cfg, estilo de playbook). Quando precisar adaptar (ex.: DNS `10.119.50.7`→`8.8.8.8`, ou Wi-Fi→intnet), deixe reversível e explique o porquê. Escolha sempre o caminho mais robusto/testável. Ver [[prova-robson-lab]].
