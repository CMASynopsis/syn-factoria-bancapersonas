<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banco Nacional - Consulta de Saldos</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body>
<jsp:include page="header.jsp"/>

<main class="main-content">
    <div class="page-header">
        <a href="${pageContext.request.contextPath}/home" class="back-link">← Volver</a>
        <h1>💰 Consulta de Saldos</h1>
        <p class="page-subtitle">Estado actual de todas tus cuentas</p>
    </div>

    <section class="section">
        <c:choose>
            <c:when test="${empty cuentas}">
                <div class="empty-state">
                    <p>No tienes cuentas activas registradas.</p>
                </div>
            </c:when>
            <c:otherwise>

                <%-- TARJETAS DE SALDO --%>
                <div class="accounts-grid" style="margin-bottom: 32px;">
                    <c:forEach var="cuenta" items="${cuentas}">
                        <div class="account-card ${cuenta.tipoCuenta == 'AHORROS' ? 'card-savings' : 'card-current'}">
                            <div class="account-card-header">
                                <span class="account-type">${cuenta.tipoCuenta}</span>
                                <span class="account-currency">${cuenta.moneda}</span>
                            </div>
                            <div class="account-number">${cuenta.numeroCuentaFormateado()}</div>
                            <div class="account-balance-label">Saldo disponible</div>
                            <div class="account-balance">
                                <fmt:formatNumber value="${cuenta.saldoDisponible}"
                                                  type="number" minFractionDigits="2"/>
                            </div>
                            <div class="account-total">
                                Saldo total:
                                <fmt:formatNumber value="${cuenta.saldo}"
                                                  type="number" minFractionDigits="2"/>
                                ${cuenta.moneda}
                            </div>
                        </div>
                    </c:forEach>
                </div>

                <%-- TABLA DETALLE --%>
                <h2 class="section-title">Detalle de cuentas</h2>
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Número de Cuenta</th>
                                <th>CCI</th>
                                <th>Tipo</th>
                                <th>Moneda</th>
                                <th>Saldo Total</th>
                                <th>Saldo Disponible</th>
                                <th>Estado</th>
                                <th>Fecha Apertura</th>
                            </tr>
                        </thead>
                        <tbody>
                            <c:forEach var="cuenta" items="${cuentas}">
                                <tr>
                                    <td><strong>${cuenta.numeroCuentaFormateado()}</strong></td>
                                    <td style="font-size:0.82rem;">${cuenta.cci}</td>
                                    <td>${cuenta.tipoCuenta}</td>
                                    <td>${cuenta.moneda}</td>
                                    <td class="amount">
                                        <fmt:formatNumber value="${cuenta.saldo}"
                                                          type="number" minFractionDigits="2"/>
                                    </td>
                                    <td class="amount">
                                        <fmt:formatNumber value="${cuenta.saldoDisponible}"
                                                          type="number" minFractionDigits="2"/>
                                    </td>
                                    <td>
                                        <span class="badge ${cuenta.estado == 'ACTIVA' ? 'badge-success' : 'badge-danger'}">
                                            ${cuenta.estado}
                                        </span>
                                    </td>
                                    <td>
                                        <fmt:formatDate value="${cuenta.fechaApertura}"
                                                        pattern="dd/MM/yyyy"/>
                                    </td>
                                </tr>
                            </c:forEach>
                        </tbody>
                    </table>
                </div>

                <%-- RESUMEN TOTALES POR MONEDA --%>
                <div style="margin-top: 24px; display: flex; gap: 16px; flex-wrap: wrap;">
                    <div class="info-box" style="flex:1; min-width:200px;">
                        <strong>Total en Soles (PEN):</strong><br/>
                        <span style="font-size:1.2rem; font-weight:700; color:var(--primary);">
                            S/
                            <c:set var="totalPEN" value="0"/>
                            <c:forEach var="cuenta" items="${cuentas}">
                                <c:if test="${cuenta.moneda == 'PEN'}">
                                    <c:set var="totalPEN" value="${totalPEN + cuenta.saldoDisponible}"/>
                                </c:if>
                            </c:forEach>
                            <fmt:formatNumber value="${totalPEN}" type="number" minFractionDigits="2"/>
                        </span>
                    </div>
                    <div class="info-box" style="flex:1; min-width:200px;">
                        <strong>Total en Dólares (USD):</strong><br/>
                        <span style="font-size:1.2rem; font-weight:700; color:var(--primary);">
                            $
                            <c:set var="totalUSD" value="0"/>
                            <c:forEach var="cuenta" items="${cuentas}">
                                <c:if test="${cuenta.moneda == 'USD'}">
                                    <c:set var="totalUSD" value="${totalUSD + cuenta.saldoDisponible}"/>
                                </c:if>
                            </c:forEach>
                            <fmt:formatNumber value="${totalUSD}" type="number" minFractionDigits="2"/>
                        </span>
                    </div>
                </div>

            </c:otherwise>
        </c:choose>
    </section>
</main>

<footer class="app-footer">
    <p>&copy; 2024 Banco Nacional. Todos los derechos reservados.</p>
</footer>
</body>
</html>
