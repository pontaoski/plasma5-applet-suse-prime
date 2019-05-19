import QtQuick 2.2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import QtQuick.Layouts 1.1

Item {

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
                if (stdoutItem.outputText.toLowerCase().includes("nvidia")) {
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
            if (stdoutItem.outputText.toLowerCase().includes("nvidia")) {
                return "kdesu /usr/sbin/prime-select intel";
            } else {
                return "kdesu /usr/sbin/prime-select nvidia";
            }
        }
    }

    // for when we want to run commands of our own
    PlasmaCore.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        onNewData: {
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
            text: qsTr("You are currently using %1.").arg(stdoutItem.activeCard)
        }
        PlasmaComponents.ToolButton {
            id: button
            iconSource: "exchange-positions"
            text: qsTr("Switch to %1").arg(stdoutItem.inactiveCard)
            onClicked: {
                executable.exec(stdoutItem.getSwitchCommand(), function(){});
            }
        }
    }
}