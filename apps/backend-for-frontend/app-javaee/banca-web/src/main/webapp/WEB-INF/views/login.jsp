<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banco Nacional - Iniciar Sesión</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body class="login-page">

<div class="login-container">
    <div class="login-brand">
        <div class="brand-logo">
            <svg viewBox="0 0 50 50" width="50" height="50" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect width="50" height="50" rx="10" fill="#1a3a6b"/>
                <path d="M8 35 L25 10 L42 35 Z" fill="#c8a84b" opacity="0.9"/>
                <rect x="12" y="35" width="26" height="4" rx="1" fill="#c8a84b"/>
                <rect x="19" y="25" width="4" height="10" fill="#1a3a6b"/>
                <rect x="27" y="25" width="4" height="10" fill="#1a3a6b"/>
            </svg>
        </div>
        <h1 class="brand-name">Banco Nacional</h1>
        <p class="brand-tagline">Banca en línea segura</p>
    </div>

    <div class="login-card">
        <h2>Iniciar Sesión</h2>

        <c:if test="${not empty errorMsg}">
            <div class="alert alert-error">
                <span class="alert-icon">⚠</span>
                <span>${errorMsg}</span>
            </div>
        </c:if>

        <form method="POST" action="${pageContext.request.contextPath}/login" class="login-form" novalidate>
            <div class="form-group">
                <label for="username">Usuario</label>
                <input type="text" id="username" name="username"
                       value="${usernameInput}"
                       placeholder="Ingrese su usuario"
                       required autocomplete="username" maxlength="50"/>
            </div>

            <div class="form-group">
                <label for="password">Contraseña</label>
                <div class="input-password-wrapper">
                    <input type="password" id="password" name="password"
                           placeholder="Ingrese su contraseña"
                           required autocomplete="current-password" maxlength="100"/>
                    <button type="button" class="toggle-password" onclick="togglePassword()">
                        <svg id="eye-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                            <circle cx="12" cy="12" r="3"/>
                        </svg>
                    </button>
                </div>
            </div>

            <button type="submit" class="btn btn-primary btn-block">
                Ingresar
            </button>
        </form>

        <div class="login-footer">
            <p>¿Problemas para ingresar? <a href="#">Contáctenos</a></p>
        </div>
    </div>

    <div class="login-security">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
        <span>Conexión segura SSL/TLS 256 bits</span>
    </div>
</div>

<script>
function togglePassword() {
    var input = document.getElementById('password');
    input.type = (input.type === 'password') ? 'text' : 'password';
}
// Validación frontend básica
document.querySelector('.login-form').addEventListener('submit', function(e) {
    var user = document.getElementById('username').value.trim();
    var pass = document.getElementById('password').value.trim();
    if (!user || !pass) {
        e.preventDefault();
        alert('Por favor complete todos los campos.');
    }
});
</script>
</body>
</html>
