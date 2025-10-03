# 📦 My Stock

Sistema de gestão de stock desenvolvido para **MyClinic**, permitindo o controlo eficiente de produtos.

---

## 🚀 Tecnologias Utilizadas
- 📱 Flutter  
- 🔥 Firebase Core & Firestore  
- 💾 Shared Preferences  
- 🌍 Intl (datas e números)  
- 📂 File Picker + Excel  
- 🔗 URL Launcher  

---

## ⚡ Instalação e Execução
```bash
git clone https://github.com/MyClinicSoftware/MyStock.git
cd MyStock
flutter pub get
flutter run
````

⚠️ É necessário configurar o **Firebase** e incluir o arquivo `firebase_options.dart` em `lib/`.

---

## 👥 Perfis de Utilizador

* 👤 **Operador** → Registra entradas e saídas, consulta produtos e lotes.
* 🛡️ **Administrador** → Além das funções do operador, pode gerir utilizadores, apagar produtos/lotes e aceder ao histórico.

---

## 📊 Funcionalidades

* 📦 **Gestão de Produtos** → cadastro, categorias e stock mínimo.
* 🧾 **Gestão de Lotes** → validade, fornecedor, preços.
* 🔔 **Alertas** → produtos abaixo do mínimo ou próximos do vencimento.
* 🗂 **Administração** → gestão de utilizadores e logs.
* 📧 **Email** *(em desenvolvimento)* → envio de pedidos de reposição a fornecedores.

---

## 🗂 Estrutura do Projeto

```
lib/
├── pages/
│   ├── home_page.dart
│   ├── produtos_page.dart
│   ├── enviar_email_page.dart
│   ├── admin_page.dart
│   └── login_page.dart
│
├── services/
│   ├── stock_service.dart
│   ├── session_service.dart
│   └── authz_service.dart
│
├── branding/
│   └── my_stock_logo.png
│
└── main.dart
```

---

## 📸 Demonstrações

(Em Breve)

* 🏠 Página inicial com atalhos
* 📋 Cards de produtos com estado do stock
* 📑 Listagem de lotes com validades e fornecedores
* ➕ Modal para registo de entrada/saída
* 🚧 Página de email em construção

