# HaxeChess ♟️

A cross-platform chess engine and interface built using the [Haxe](https://haxe.org/) programming language and the [OpenFL](https://www.openfl.org/) framework.

## 🚀 Features

* **Cross-Platform:** Compile to HTML5, Windows, macOS, Linux, Android, or iOS from a single codebase.
* **OpenFL Powered:** Uses hardware-accelerated rendering for smooth piece movement.
* **Move Validation:** Full implementation of chess rules (Castling, En Passant, Promotion).
* **Clean Architecture:** Modular code structure separating game logic from the rendering layer.

## 🛠️ Requirements

To build this project, you need:

1.  [Haxe](https://haxe.org/download/) (4.0.0 or newer recommended)
2.  [OpenFL](https://www.openfl.org/download/)

## 📦 Installation

1.  **Install Haxe libraries:**
    ```bash
    haxelib install openfl
    ```

2.  **Setup OpenFL (if you haven't already):**
    ```bash
    haxelib run openfl setup
    ```

3.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Maw-YT/HaxeChess.git](https://github.com/Maw-YT/HaxeChess.git)
    cd HaxeChess
    ```

## 🎮 Compilation & Running

You can test the project on various targets:

* **Test in Browser (HTML5):**
    ```bash
    openfl test html5
    ```
* **Test on Desktop (Windows/Mac/Linux):**
    ```bash
    openfl test windows   # or 'mac' / 'linux'
    ```

## ⬇️ Download

You can download the latest pre-compiled version for Windows from the [Releases](https://github.com/Maw-YT/HaxeChess/releases) page. 

*Just download the `.zip`, extract it, and run `Chess.exe`!*

## 📂 Project Structure

* `Source/`: Contains the `.hx` source code.
    * `Main.hx`: Entry point of the application.
    * `managers/`: Chess move validation and board state.
    * `renderers/`: Rendering board and pieces.
    * `Pieces/`: Folder that holds all the pieces.
    * `ui/`: Folder holds all UI stuff.
    * `utils/`: Utilites.
    * `config/`: Configurion.
    * `controllers/`: Game Controaller.
* `Assets/`: Images (pieces)
* `project.xml`: OpenFL configuration file.

## 🤝 Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
*Developed by [Maw-YT](https://github.com/Maw-YT)*
