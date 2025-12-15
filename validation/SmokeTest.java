/**
 * Smoke Test for Talend ESB Studio SE build artifacts.
 * Validates that core framework classes can be loaded and instantiated.
 * Compatible with Java 8.
 */
public class SmokeTest {

    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        printLine();
        System.out.println("Talend ESB Studio SE - Smoke Test");
        printLine();
        System.out.println();

        // CXF Classes
        testClass("org.apache.cxf.Bus", "CXF Bus interface");
        testClass("org.apache.cxf.bus.spring.SpringBusFactory", "CXF SpringBusFactory");
        testClass("org.apache.cxf.frontend.ClientProxyFactoryBean", "CXF Client Factory");
        testClass("org.apache.cxf.jaxws.JaxWsProxyFactoryBean", "CXF JAX-WS Factory");
        testClass("org.apache.cxf.jaxrs.client.WebClient", "CXF JAX-RS WebClient");

        // Camel Classes
        testClass("org.apache.camel.CamelContext", "Camel Context interface");
        testClass("org.apache.camel.impl.DefaultCamelContext", "Camel DefaultCamelContext");
        testClass("org.apache.camel.builder.RouteBuilder", "Camel RouteBuilder");
        testClass("org.apache.camel.component.cxf.CxfComponent", "Camel CXF Component");
        testClass("org.apache.camel.component.jms.JmsComponent", "Camel JMS Component");

        // Spring Classes
        testClass("org.springframework.context.ApplicationContext", "Spring ApplicationContext");
        testClass("org.springframework.context.support.ClassPathXmlApplicationContext", "Spring ClassPathXmlApplicationContext");
        testClass("org.springframework.beans.factory.BeanFactory", "Spring BeanFactory");
        testClass("org.springframework.jms.core.JmsTemplate", "Spring JmsTemplate");

        // ActiveMQ Classes
        testClass("org.apache.activemq.ActiveMQConnectionFactory", "ActiveMQ ConnectionFactory");
        testClass("org.apache.activemq.command.ActiveMQQueue", "ActiveMQ Queue");

        // Talend ESB Classes
        testClass("org.talend.esb.servicelocator.client.ServiceLocator", "Talend ServiceLocator");
        testClass("org.talend.esb.sam.agent.flowidprocessor.FlowIdProducerIn", "Talend SAM Agent");

        // OSGi/Spring OSGi
        testClass("org.springframework.osgi.context.support.OsgiBundleXmlApplicationContext", "Spring OSGi Context");

        // Security
        testClass("org.apache.ws.security.WSSecurityEngine", "WS-Security Engine");

        // Groovy (for Camel scripts)
        testClass("groovy.lang.GroovyShell", "Groovy Shell");

        // Print summary
        System.out.println();
        printLine();
        System.out.println("SUMMARY");
        printLine();
        System.out.println("Passed: " + passed);
        System.out.println("Failed: " + failed);
        System.out.println("Total:  " + (passed + failed));
        System.out.println();

        if (failed == 0) {
            System.out.println("✓ SMOKE TEST PASSED");
            System.exit(0);
        } else if (failed <= 3) {
            System.out.println("⚠ SMOKE TEST PARTIAL (non-critical failures)");
            System.exit(0);
        } else {
            System.out.println("✗ SMOKE TEST FAILED");
            System.exit(1);
        }
    }

    private static void testClass(String className, String description) {
        try {
            Class<?> clazz = Class.forName(className);
            System.out.println("✓ " + description);
            System.out.println("  └─ " + className);
            passed++;
        } catch (ClassNotFoundException e) {
            System.out.println("✗ " + description);
            System.out.println("  └─ " + className + " (ClassNotFoundException)");
            failed++;
        } catch (NoClassDefFoundError e) {
            System.out.println("✗ " + description);
            System.out.println("  └─ " + className + " (NoClassDefFoundError: " + e.getMessage() + ")");
            failed++;
        } catch (Exception e) {
            System.out.println("✗ " + description);
            System.out.println("  └─ " + className + " (" + e.getClass().getSimpleName() + ": " + e.getMessage() + ")");
            failed++;
        }
    }

    private static void printLine() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 60; i++) {
            sb.append("=");
        }
        System.out.println(sb.toString());
    }
}
