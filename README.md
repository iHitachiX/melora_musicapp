# Melora - Music Player for 17mov_Phone

A custom music app for **17mov_Phone**, designed for playing properly licensed, royalty-free music inside your FiveM server.

This version is a rewritten and adapted implementation based on the **lb-phone music app** from **albertheprince**

---

## ✨ Features
- Play your favourite music
- Downloadable via the 17mov_Phone App Store
- Dynamic playback behavior based on vehicle speed
- Displays song thumbnail and title
- Automatically stops audio on player exit/logout
- Playlist system (stored using KVP across sessions/characters)

---

## 🔧 Dependencies
- [17mov_Phone](https://17movement.net/products/17mov_phone)
- [xSound](https://github.com/Xogy/xsound/)

---

## 🛠️ Tech Stack

The UI has been fully rewritten from **React + Redux** to **Svelte 5** using Vite.

**Bundle size:** ~20kb instead of ~70kb

---

## 📜 Credits

- Original concept and implementation:  
  https://github.com/alberttheprince/lb-musicapp

- This version:
  - Fully rewritten and adapted for **17mov_Phone**
  - UI rewritten in **Svelte 5** with Vite
  - Adjusted architecture and integration
  - Modified UI/UX flow and functionality
