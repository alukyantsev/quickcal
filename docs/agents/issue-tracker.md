# Issue tracker: Local Markdown

Спецификации и задачи этого репозитория хранятся локально в `.scratch/`.

## Conventions

- Одна функциональность на каталог: `.scratch/<feature-slug>/`.
- Спецификация: `.scratch/<feature-slug>/spec.md`.
- Задачи реализации: `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, один файл на задачу, нумерация с `01`.
- Состояние triage фиксируется строкой `Status:` в начале файла.
- Комментарии и история обсуждения добавляются в конец файла под `## Comments`.

## When a skill says "publish to the issue tracker"

Создайте файл в `.scratch/<feature-slug>/`, при необходимости создав каталог.

## When a skill says "fetch the relevant ticket"

Прочитайте файл по указанному пути или номеру задачи.
