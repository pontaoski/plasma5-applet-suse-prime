import QtQuick 2.2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import QtQuick.Layouts 1.1

Item {
    id: root;
    property bool needsReboot: false

    // thing that handles getting status
    Item {
        property string outputText:   ""

        property string activeCard:   ""
        property string inactiveCard: ""

        id: stdoutItem
        PlasmaCore.DataSource {
            id: getWithStdout
            engine: "executable"
            connectedSources: []
            onNewData: {
                var exitCode = data["exit code"]
                var exitStatus = data["exit status"]
                var stdout = data["stdout"]
                var stderr = data["stderr"]
                exited(sourceName, exitCode, exitStatus, stdout, stderr)
                disconnectSource(sourceName) // cmd finished
            }
            function exec(cmd) {
                if (cmd) {
                    connectSource(cmd)
                }
            }
            signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
        }
        
        Connections {
            target: getWithStdout
            onExited: {
                stdoutItem.outputText = stdout.replace('\n', ' ').trim()
                if (stdoutItem.outputText.toLowerCase().includes(": nvidia")) {
                    stdoutItem.activeCard = "NVidia"
                    stdoutItem.inactiveCard = "Intel"
                } else {
                    stdoutItem.activeCard = "Intel"
                    stdoutItem.inactiveCard = "NVidia"
                }
            }
        }

        Timer {
            id: timer
            interval: 500
            running: true
            repeat: true
            onTriggered: {
                getWithStdout.exec("/usr/sbin/prime-select get-current")
            }
            Component.onCompleted: {
                triggered()
            }
        }

        function getSwitchCommand() {
            if (stdoutItem.outputText.toLowerCase().includes(": nvidia")) {
                return "kdesu /usr/sbin/prime-select boot intel";
            } else {
                return "kdesu /usr/sbin/prime-select boot nvidia";
            }
        }
    }

    // for switching
    PlasmaCore.DataSource {
        id: switchCmd
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        onNewData: {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]

            if (exitCode == 0) {
                root.needsReboot = true
                rebootCmd.exec("kdialog --yesno \"" + qsTr("In order to apply changes, you need to reboot. Reboot now?") + "\"", function(){});
            } else {
                root.needsReboot = false
            }
            
            if (callbacks[sourceName] !== undefined) {
                callbacks[sourceName](stdout);
            }
            
            exited(sourceName, stdout)
            disconnectSource(sourceName) // cmd finished
        }
        
        function exec(cmd, onNewDataCallback) {
            if (onNewDataCallback !== undefined){
                callbacks[cmd] = onNewDataCallback
            }
            connectSource(cmd)
                    
        }
        signal exited(string sourceName, string stdout)

    }

    PlasmaCore.DataSource {
        id: rebootCmd
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        onNewData: {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]

            if (exitCode == 0) {
                executable.exec("qdbus-qt5 org.kde.ksmserver /KSMServer logout 1 1 3");
            } else {
                
            }
            
            if (callbacks[sourceName] !== undefined) {
                callbacks[sourceName](stdout);
            }
            
            exited(sourceName, stdout)
            disconnectSource(sourceName) // cmd finished
        }
        
        function exec(cmd, onNewDataCallback) {
            if (onNewDataCallback !== undefined){
                callbacks[cmd] = onNewDataCallback
            }
            connectSource(cmd)
                    
        }
        signal exited(string sourceName, string stdout)

    }

    PlasmaCore.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        onNewData: {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]
            
            if (callbacks[sourceName] !== undefined) {
                callbacks[sourceName](stdout);
            }
            
            exited(sourceName, stdout)
            disconnectSource(sourceName) // cmd finished
        }
        
        function exec(cmd, onNewDataCallback) {
            if (onNewDataCallback !== undefined){
                callbacks[cmd] = onNewDataCallback
            }
            connectSource(cmd)
                    
        }
        signal exited(string sourceName, string stdout)
    }

    Layout.minimumHeight: label.height + button.height
    Layout.maximumHeight: Layout.minimumHeight
    Column {
        PlasmaExtras.Heading {
            id: label
            font.pointSize: 14
            text: !root.needsReboot ? qsTr("You are currently using %1.").arg(stdoutItem.activeCard) : qsTr("Reboot pending.")
        }
        Row {
            PlasmaComponents.ToolButton {
                id: button
                enabled: !root.needsReboot
                iconSource: "exchange-positions"
                text: qsTr("Switch to %1").arg(stdoutItem.inactiveCard)
                onClicked: {
                    switchCmd.exec(stdoutItem.getSwitchCommand(), function(){});
                }
            }
            PlasmaComponents.ToolButton {
                visible: root.needsReboot
                id: reboot
                iconSource: "system-reboot"
                text: qsTr("Reboot")
                onClicked: {
                    executable.exec("qdbus-qt5 org.kde.ksmserver /KSMServer logout 1 1 3", function(){});
                }
            }
        }
    }
}
