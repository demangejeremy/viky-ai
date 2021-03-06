# encoding: utf-8

require 'test_helper'

module Nls

  module EndpointInterpret

    class TestRegex < NlsTestCommon

      def setup
        super

        Nls.remove_all_packages

        Interpretation.default_locale = "en"

        Nls.package_update(create_package)
      end

      def create_package
        package = Package.new("package")

        email = package.new_interpretation("email", { scope: "private" })
        email << Expression.new("@{email}", aliases: { email: Alias.regex("[a-z]+@[a-z]+\.[a-z]+") }, solution: "`{ email: email }`")

        emails = package.new_interpretation("emails", { scope: "public" })
        emails << Expression.new("@{email}", aliases: { email: email })
        emails << Expression.new("@{email} @{emails}", aliases: { email: email, emails: emails })

        possibly_empty = package.new_interpretation("possibly_empty", { scope: "public" })
        possibly_empty << Expression.new("@{maison}", aliases: { maison: Alias.regex("(maison|)") }, solution: "`{ maison: maison }`")

        package
      end

      # Tests

      def test_regex

        expected = {
          interpretation: "emails",
          solution: [{ email: "patrick@pertimm.com" }]
        }
        check_interpret("mail patrick@pertimm.com",        expected)

        expected = {
          interpretation: "emails",
          solution: [
          { email: "patrick@pertimm.com" },
          { email: "sebastien@pertimm.com" },
          ]
        }
        check_interpret("mail patrick@pertimm.com sebastien@pertimm.com",        expected)
      end

      def test_regex_multiple
        expected = {
          interpretation: "emails",
          solution: [{ email: "patrick@pertimm.com" }]
        }
        500.times do
          check_interpret("mail patrick@pertimm.com",        expected)
        end
      end

      def test_regex_empty_possibility
        check_interpret("maison", interpretation: "possibly_empty", solution: { maison: "maison" })
        check_interpret("cheval", interpretation: nil)
      end

    end
  end

end
