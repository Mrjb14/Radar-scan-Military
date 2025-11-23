// RadarWatchFaceView.mc
// Watchface Radar Militaire avec scan rotatif
// Optimisée pour rafraîchissement 1Hz

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Math;

class NewWatch1View extends WatchUi.WatchFace {

    // Constantes de couleurs (monochrome vert)
    private const BG_COLOR = 0x0A0F0A;
    private const RADAR_GREEN = 0x00FF00;
    private const GLOW_COLOR = 0x1A3A1A;
    private const TARGET_RED = 0xFF0000;
    
    // Angle de la ligne de scan
    private var scanAngle = 0;
    private const SCAN_INCREMENT = 6; // 6° par seconde = 1 tour/minute
    
    // Dimensions
    private var screenWidth;
    private var screenHeight;
    private var centerX;
    private var centerY;
    private var scale;
    
    // Polices
    private var hugeFont;
    private var mediumFont;
    private var smallFont;
    private var tinyFont;

    // Polices personnalisées
    private var orbitronTime;
    private var orbitronSmall;
    
    // État
    private var needsFullRedraw = true;
    private var updateCounter = 0;

    // Cibles aléatoires (angle, rayon, timestamp apparition)
    private var targets = [];
    private const MAX_TARGETS = 3;
    private const TARGET_DURATION = 5; // secondes

    function initialize() {
        WatchFace.initialize();
        scanAngle = 0;
    }

    function onLayout(dc) {
        screenWidth = dc.getWidth();
        screenHeight = dc.getHeight();
        centerX = screenWidth / 2;
        centerY = screenHeight / 2;
        scale = screenWidth / 240.0;
        
        // Polices système
        hugeFont = Graphics.FONT_NUMBER_HOT;
        mediumFont = Graphics.FONT_MEDIUM;
        smallFont = Graphics.FONT_SMALL;
        tinyFont = Graphics.FONT_XTINY;

        // Polices personnalisées Orbitron
        orbitronTime = WatchUi.loadResource(Rez.Fonts.OrbitronTime);
        orbitronSmall = WatchUi.loadResource(Rez.Fonts.OrbitronSmall);
    }

    function onShow() {
        needsFullRedraw = true;
    }

    function onUpdate(dc) {
        updateCounter++;
        
        // Angle de scan basé sur les secondes (0-59 -> 0-354°)
        var clockTime = System.getClockTime();
        scanAngle = clockTime.sec * 6; // 6° par seconde = 360° en 60 secondes
        
        if (needsFullRedraw) {
            drawStaticElements(dc);
            needsFullRedraw = false;
        } else {
            clearDynamicAreas(dc);
        }
        
        // Éléments dynamiques
        drawScanLine(dc);
        drawScanTrail(dc);
        updateTargets(clockTime.sec);
        drawTargets(dc);
        drawTime(dc);
        drawDate(dc);
        drawAllBlips(dc);
        drawStatusIndicators(dc);
    }

    // Dessiner éléments statiques
    function drawStaticElements(dc) {
        dc.setAntiAlias(true);
        
        // Fond noir
        dc.setColor(BG_COLOR, BG_COLOR);
        dc.fillCircle(centerX, centerY, centerX);
        
        // Glow central
        drawCentralGlow(dc);
        
        // Grille de fond
        drawGrid(dc);
        
        // Cercles concentriques
        drawConcentricCircles(dc);
        
        // Croix centrale
        drawCentralCross(dc);
        
        // Marqueurs de degrés
        drawDegreeMarkers(dc);
        
        // Coins interface
        drawInterfaceCorners(dc);
        
        // Point central
        drawCenterDot(dc);
        
        // Labels statiques
        drawStaticLabels(dc);
        
        // Échelle de distance
        drawDistanceScale(dc);
    }

    // Glow central
    function drawCentralGlow(dc) {
        var glowSteps = [
            [100, 0.8],
            [80, 0.6],
            [60, 0.4],
            [40, 0.2]
        ];

        for (var i = 0; i < glowSteps.size(); i++) {
            dc.setColor(GLOW_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, (glowSteps[i][0] * scale).toNumber());
        }
    }

    // Grille
    function drawGrid(dc) {
        dc.setColor(GLOW_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var gridSize = (20 * scale).toNumber();

        // Lignes verticales
        for (var x = centerX % gridSize; x < screenWidth; x += gridSize) {
            dc.drawLine(x.toNumber(), 0, x.toNumber(), screenHeight);
        }

        // Lignes horizontales
        for (var y = centerY % gridSize; y < screenHeight; y += gridSize) {
            dc.drawLine(0, y.toNumber(), screenWidth, y.toNumber());
        }
    }

    // Cercles concentriques
    function drawConcentricCircles(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var radii = [110, 90, 70, 50];
        for (var i = 0; i < radii.size(); i++) {
            dc.drawCircle(centerX, centerY, (radii[i] * scale).toNumber());
        }
    }

    // Croix centrale
    function drawCentralCross(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        // Vertical
        dc.drawLine(centerX, (10 * scale).toNumber(), centerX, (230 * scale).toNumber());
        // Horizontal
        dc.drawLine((10 * scale).toNumber(), centerY, (230 * scale).toNumber(), centerY);
    }

    // Marqueurs de degrés
    function drawDegreeMarkers(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);

        var markers = [
            [centerX, (18 * scale).toNumber(), "000"],
            [(225 * scale).toNumber(), (centerY + 4*scale).toNumber(), "090"],
            [centerX, (232 * scale).toNumber(), "180"],
            [(15 * scale).toNumber(), (centerY + 4*scale).toNumber(), "270"]
        ];

        for (var i = 0; i < markers.size(); i++) {
            dc.drawText(markers[i][0], markers[i][1], tinyFont, markers[i][2],
                       Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Coins interface
    function drawInterfaceCorners(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        var margin = (20 * scale).toNumber();
        var length = (15 * scale).toNumber();

        // Haut gauche
        dc.drawLine(margin, margin, margin, margin + length);
        dc.drawLine(margin, margin, margin + length, margin);

        // Haut droit
        dc.drawLine(screenWidth - margin, margin, screenWidth - margin, margin + length);
        dc.drawLine(screenWidth - margin, margin, screenWidth - margin - length, margin);

        // Bas gauche
        dc.drawLine(margin, screenHeight - margin, margin, screenHeight - margin - length);
        dc.drawLine(margin, screenHeight - margin, margin + length, screenHeight - margin);

        // Bas droit
        dc.drawLine(screenWidth - margin, screenHeight - margin,
                   screenWidth - margin, screenHeight - margin - length);
        dc.drawLine(screenWidth - margin, screenHeight - margin,
                   screenWidth - margin - length, screenHeight - margin);
    }

    // Point central
    function drawCenterDot(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, (3 * scale).toNumber());

        dc.setColor(BG_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, (1.5 * scale).toNumber());
    }

    // Labels statiques
    function drawStaticLabels(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);

        // Mode "TACTICAL"
        dc.drawText((40 * scale).toNumber(), (215 * scale).toNumber(), tinyFont, "TACTICAL",
                   Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Échelle de distance
    function drawDistanceScale(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var x1 = (25 * scale).toNumber();
        var x2 = (35 * scale).toNumber();
        var y = (215 * scale).toNumber();

        dc.drawLine(x1, y, x2, y);
        dc.drawLine(x1, y, x1, (y - 5*scale).toNumber());
        dc.drawLine(x2, y, x2, (y - 5*scale).toNumber());

        dc.drawText((30 * scale).toNumber(), (y - 8*scale).toNumber(), tinyFont, "10M",
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Nettoyer zones dynamiques
    function clearDynamicAreas(dc) {
        dc.setColor(BG_COLOR, BG_COLOR);

        // Zone complète car la ligne de scan traverse tout
        dc.fillCircle(centerX, centerY, (115 * scale).toNumber());

        // Redessiner les éléments statiques visibles
        drawConcentricCircles(dc);
        drawCentralCross(dc);
    }

    // Ligne de scan rotative
    function drawScanLine(dc) {
        var radius = 110 * scale;
        var radians = Math.toRadians(scanAngle - 90);
        var endX = (centerX + radius * Math.cos(radians)).toNumber();
        var endY = (centerY + radius * Math.sin(radians)).toNumber();

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(centerX, centerY, endX, endY);

        // Triangle à l'extrémité
        drawScanTriangle(dc, endX, endY, scanAngle);
    }

    // Triangle de direction
    function drawScanTriangle(dc, x, y, angle) {
        var size = 5 * scale;
        var radians = Math.toRadians(angle - 90);

        // Calculer les 3 points du triangle
        var points = [
            [(x + size * Math.cos(radians)).toNumber(), (y + size * Math.sin(radians)).toNumber()],
            [(x + size * Math.cos(radians + 2.5)).toNumber(), (y + size * Math.sin(radians + 2.5)).toNumber()],
            [(x + size * Math.cos(radians - 2.5)).toNumber(), (y + size * Math.sin(radians - 2.5)).toNumber()]
        ];

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);
    }

    // Traînée du scan
    function drawScanTrail(dc) {
        var radius = (110 * scale).toNumber();
        var trailSpan = 45;
        var startAngle = scanAngle - trailSpan;
        var endAngle = scanAngle;

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((15 * scale).toNumber());
        dc.drawArc(centerX, centerY, radius,
                   Graphics.ARC_COUNTER_CLOCKWISE,
                   startAngle, endAngle);
    }

    // Heure
    function drawTime(dc) {
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [
            clockTime.hour.format("%02d"),
            clockTime.min.format("%02d")
        ]);

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (75 * scale).toNumber(), orbitronTime, timeString,
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Date
    function drawDate(dc) {
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$.$3$", [
            today.day_of_week.toUpper().substring(0, 3),
            today.day.format("%02d"),
            today.month.toUpper().substring(0, 3)
        ]);

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (118 * scale).toNumber(), orbitronSmall, dateString,
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Secondes
    function drawSeconds(dc) {
        var clockTime = System.getClockTime();
        var secString = ":" + clockTime.sec.format("%02d");

        // Cadre
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle((centerX - 15*scale).toNumber(), (134*scale).toNumber(),
                               (30*scale).toNumber(), (12*scale).toNumber(), (2*scale).toNumber());

        // Valeur
        dc.drawText(centerX, (136 * scale).toNumber(), orbitronSmall, secString,
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Dessiner tous les blips
    function drawAllBlips(dc) {
        // HR à 10h (305°) - plus vers le bord
        var hrPos = getCircularPosition(305, 85);
        var hr = getCurrentHeartRate();
        drawBlip(dc, hrPos[0], hrPos[1], "HR", hr != null ? hr.toString() : "--", 0);

        // Steps à 2h (55°) - plus vers le bord
        var stepsPos = getCircularPosition(55, 85);
        var info = ActivityMonitor.getInfo();
        drawBlip(dc, stepsPos[0], stepsPos[1], "STEPS", info.steps.toString(), 0.33);

        // Battery à 6h (180°)
        var batPos = getCircularPosition(180, 70);
        var stats = System.getSystemStats();
        var batString = stats.battery.toNumber() + "%";
        drawBlip(dc, batPos[0], batPos[1], "PWR", batString, 0.66);
    }

    // Calculer position circulaire
    function getCircularPosition(angle, radius) {
        var radians = Math.toRadians(angle - 90);
        var x = (centerX + radius * scale * Math.cos(radians)).toNumber();
        var y = (centerY + radius * scale * Math.sin(radians)).toNumber();
        return [x, y];
    }

    // Dessiner un blip avec pulsation
    function drawBlip(dc, x, y, label, value, phase) {
        // Calculer pulsation
        var pulse = Math.sin((updateCounter + phase * 3) * Math.PI / 3);
        var radius = ((2 + pulse * 4) * scale).toNumber();

        // Cercles concentriques
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (8 * scale).toNumber()); // Fond (opacité simulée)
        dc.fillCircle(x, y, (5 * scale).toNumber()); // Moyen
        dc.fillCircle(x, y, radius);    // Centre pulsant

        // Crosshair
        drawCrosshair(dc, x, y);

        // Label
        dc.drawText(x, (y - 20*scale).toNumber(), orbitronSmall, label,
                   Graphics.TEXT_JUSTIFY_CENTER);

        // Valeur
        dc.drawText(x, (y + 12*scale).toNumber(), orbitronSmall, value,
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Crosshair
    function drawCrosshair(dc, x, y) {
        var size = (12 * scale).toNumber();
        var gap = (8 * scale).toNumber();

        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        dc.drawLine(x - size, y, x - gap, y);
        dc.drawLine(x + gap, y, x + size, y);
        dc.drawLine(x, y - size, x, y - gap);
        dc.drawLine(x, y + gap, x, y + size);
    }

    // Indicateurs de statut
    function drawStatusIndicators(dc) {
        dc.setColor(RADAR_GREEN, Graphics.COLOR_TRANSPARENT);

        // "SCAN" centré en haut
        dc.drawText(centerX, (25 * scale).toNumber(), orbitronSmall, "SCAN",
                   Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Mettre à jour les cibles
    function updateTargets(currentSec) {
        // Supprimer les cibles expirées
        var newTargets = [];
        for (var i = 0; i < targets.size(); i++) {
            var age = currentSec - targets[i][2];
            if (age < 0) { age += 60; } // Gestion du passage de 59 à 0
            if (age < TARGET_DURATION) {
                newTargets.add(targets[i]);
            }
        }
        targets = newTargets;

        // Ajouter une nouvelle cible aléatoirement (20% de chance par seconde)
        if (targets.size() < MAX_TARGETS && Math.rand() % 5 == 0) {
            var angle = scanAngle + (Math.rand() % 30) - 15; // Proche de la ligne de scan
            var radius = 40 + (Math.rand() % 50); // Entre 40 et 90
            targets.add([angle, radius, currentSec]);
        }
    }

    // Dessiner les cibles
    function drawTargets(dc) {
        dc.setColor(TARGET_RED, Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < targets.size(); i++) {
            var angle = targets[i][0];
            var radius = targets[i][1];
            var pos = getCircularPosition(angle, radius);

            // Cercle cible rouge
            dc.setPenWidth(1);
            dc.drawCircle(pos[0], pos[1], (6 * scale).toNumber());
            dc.fillCircle(pos[0], pos[1], (2 * scale).toNumber());
        }
    }

    // Obtenir fréquence cardiaque
    function getCurrentHeartRate() {
        var activityInfo = Activity.getActivityInfo();
        if (activityInfo != null && activityInfo.currentHeartRate != null) {
            return activityInfo.currentHeartRate;
        }
        
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return sample.heartRate;
        }
        
        return null;
    }

    function onEnterSleep() {
        needsFullRedraw = true;
    }

    function onExitSleep() {
        needsFullRedraw = true;
    }

    function onHide() {
    }
}
