public class Main {
    public static void main(String[] args) {
        System.out.println("Servidor Java del laboratorio iniciado correctamente");
        try {
            // Mantiene el hilo ejecutándose para que el contenedor no se cierre
            Thread.currentThread().join();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
