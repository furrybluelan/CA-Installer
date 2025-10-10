import java.io.FileInputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Arrays;

public class CertName {

    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("Usage: java CertName <path-to-pem>");
            return;
        }

        String pemPath = args[0];

        try (InputStream in = new FileInputStream(pemPath)) {
            // 使用证书工厂读取 X.509 证书
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            X509Certificate cert = (X509Certificate) cf.generateCertificate(in);

            // 获取 Subject Name 的编码（DER）
            byte[] subjectDer = cert.getSubjectX500Principal().getEncoded();

            // OpenSSL 默认使用 MD5 或 SHA1 的前4字节做 little-endian hash
            // Android 现在大多数是 SHA1 对应 OpenSSL 的旧实现
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            byte[] digest = md5.digest(subjectDer);

            // 取前4字节，little-endian 转成 int
            int hashInt = ((digest[3] & 0xFF) << 24) | ((digest[2] & 0xFF) << 16)
                        | ((digest[1] & 0xFF) << 8) | (digest[0] & 0xFF);

            String hashHex = String.format("%08x", hashInt);

            // 系统证书文件名第一个序号一般为 .0
            String sysCertName = hashHex + ".0";

            System.out.println(sysCertName);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}