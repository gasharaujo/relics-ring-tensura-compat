# Relics Tensura EP Compat

Patch de compatibilidade para Tensura Oblivion (Minecraft 1.21.1 / NeoForge).

A habilidade **Gluttony/Gula** do Ring of the Seven Deadly Sins percorre todos os
atributos do jogador. O Tensura calcula o EP exibido somando Aura Máxima e
Magículas Máximas. Sem este patch, o anel multiplica esses valores e seus limites
espirituais, fazendo o EP exibido variar com a fome sem representar o progresso
armazenado. A mesma lógica também multiplica o atributo de escala do Minecraft,
alterando o tamanho do jogador.

O patch intercepta apenas essa aplicação:

- mantém todos os outros bônus e penalidades da Gula;
- impede o multiplicador em Aura Máxima, Magículas Máximas e seus limites
  espirituais;
- impede o multiplicador no tamanho do jogador (`minecraft:generic.scale`);
- remove no próximo tick qualquer modificador transitório de EP criado pelo anel.

## Instalação

A lógica original do anel é executada apenas no lado lógico do servidor. Em um
servidor dedicado, o JAR é obrigatório no servidor e opcional no cliente. Em
singleplayer/LAN, ele deve ficar na pasta `mods` do cliente, porque o cliente
também hospeda o servidor integrado. Para manter cliente e servidor com o mesmo
pack, é seguro instalar nos dois lados.

## Compilar

```powershell
.\build.ps1
```

Para compilar, verificar e instalar na instância:

```powershell
.\build.ps1 -Install
```
