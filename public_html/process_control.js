/*
 * Copyright 2011 Exavideo LLC.
 * 
 * This file is part of Exadeck.
 * 
 * Exadeck is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Exadeck is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with Exadeck.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

function getJson(sourceurl, callback) {
    jQuery.ajax({
        url: sourceurl,
        dataType: "json",
        error: function(jqxhr, textStatus) {
            //alert("Communication failure: " + textStatus);
        },
        success: function(data) {
            callback(data);
        }
    });
}

function putJson(desturl, obj) {
    jQuery.ajax({
        type: "PUT",
        url: desturl,
        contentType: "application/json",
        data: JSON.stringify(obj),
        error: function(jqxhr, textStatus) {
            //alert("Communication error: " + textStatus);  
        }
    });
}

$.fn.updateProcess = function() {
    var url = $(this).data('url');
    var target = $(this);
    getJson(url, function(data) { target.loadData(data) });
}

$.fn.loadData = function(data) {
    $(this).find("#command").val(data.cmd);

    $(this).find("#time").text(data.time);
    $(this).find("#bitrate").text(data.bitrate);
    $(this).find("#size").text(data.size);
    $(this).find("#fps").text(data.fps);
    $(this).find("#frames_encoded").text(data.frames_encoded);

    if (data.is_running) {
        $(this).addClass("processRunning");
        $(this).removeClass("processStopped");
    } else {
        $(this).addClass("processStopped");
        $(this).removeClass("processRunning");
    }
}

$.fn.updateCommand = function() {
    var cmd = $(this).find("#command").val()
    var url = $(this).data('url');

    putJson(url, { 'cmd' : cmd });
}

$.fn.startProcess = function() {
    var url = $(this).data('url');
    putJson(url + '/start', { });
}

$.fn.stopProcess = function() {
    var url = $(this).data('url');
    putJson(url + '/stop', { });
}

$.fn.findProcess = function() {
    return $(this).closest(".process");
}

$.fn.installHandlers = function() {
    $(this).find("#command").change(function() { 
        $(this).findProcess().updateCommand() 
    });

    $(this).find("#start").click(function() {
        $(this).findProcess().startProcess();
    });

    $(this).find("#stop").click(function() {
        $(this).findProcess().stopProcess();
    });
}

function updateTimeout() {
    $(".process").each(function(i,e) {
        $(e).updateProcess( );
    });

    setTimeout(updateTimeout, 1000);
}

$(document).ready(function() {
    getJson('/processes', function(data) {
        $.each(data, function(i,e) {
            var element = $(".processProto")
                .clone()
                .removeClass("processProto")
                .addClass("process");

            element.data('url', '/process/' + i);
            element.loadData(e);
            element.installHandlers( );
            $("#container").append(element);
        });
    });

    setTimeout(updateTimeout, 1000);
});
