import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Arrays;

public class ScriptExecutor {

    // Shell script embedded as a string
    private static final String SHELL_SCRIPT = """
            #!/bin/bash
            echo "Hello from the shell script!"
            echo "Parameter 1: $1"
            echo "Parameter 2: $2"
            # Add more shell commands as needed
            """;

    public static void main(String[] args) {
        try {
            // Execute the shell script with parameters
            executeShellScript("arg1", "arg2");
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    public static void executeShellScript(String... scriptArgs) throws IOException, InterruptedException {
        // Create a temporary file to store the shell script
        File tempScript = File.createTempFile("tempScript", ".sh");
        tempScript.setExecutable(true);

        // Write the shell script content to the temporary file
        try (FileWriter writer = new FileWriter(tempScript)) {
            writer.write(SHELL_SCRIPT);
        }

        // Build the command to run the shell script with arguments
        String[] command = new String[scriptArgs.length + 1];
        command[0] = tempScript.getAbsolutePath();
        System.arraycopy(scriptArgs, 0, command, 1, scriptArgs.length);

        // Start the process
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.inheritIO(); // Optional: Inherit I/O for easier debugging
        Process process = processBuilder.start();

        // Wait for the process to finish
        process.waitFor();

        // Clean up: delete the temporary file
        tempScript.delete();
    }
}