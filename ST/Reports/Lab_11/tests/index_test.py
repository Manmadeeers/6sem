from selenium.webdriver.common.by import By


def test_page_contains_visible_form(open_form_page):
    form = open_form_page.find_element(By.TAG_NAME, "form")
    assert form.is_displayed()


def test_form_contains_expected_input_types(open_form_page):
    inputs = open_form_page.find_elements(By.CSS_SELECTOR, "form .form-group input")
    input_types = [field.get_attribute("type") for field in inputs]

    assert len(inputs) == 5
    assert input_types == ["text", "tel", "email", "date", "password"]


def test_labels_match_expected_order(open_form_page):
    labels = open_form_page.find_elements(By.CSS_SELECTOR, "form .form-group label")
    label_texts = [label.text.strip() for label in labels]

    assert label_texts == [
        "Name:",
        "Phone:",
        "Email:",
        "Date of birth:",
        "Password:",
    ]


def test_input_focus_and_styling_are_applied(open_form_page):
    first_input = open_form_page.find_element(By.CSS_SELECTOR, ".form-group input")
    first_input.click()

    active_tag = open_form_page.execute_script("return document.activeElement.tagName")
    border_radius = open_form_page.execute_script(
        "return getComputedStyle(arguments[0]).borderRadius;",
        first_input,
    )
    body_background = open_form_page.execute_script(
        "return getComputedStyle(document.body).backgroundImage;"
    )

    assert active_tag == "INPUT"
    assert border_radius == "12px"
    assert "gradient" in body_background.lower()
