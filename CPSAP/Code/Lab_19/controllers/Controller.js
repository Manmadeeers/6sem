using Microsoft.AspNetCore.Mvc;
using Models;

namespace Controllers
{
    public class StudentsController : Controller
    {
        [HttpGet("/students")]
        public IActionResult GetAllStudents()
        {
            return Ok(Student.GetAll());
        }

        [HttpGet("/students/{id}")]
        public IActionResult GetStudentById(int id)
        {
            var foundStudent = Student.GetById(id);
            if (foundStudent == null)
                return NotFound(new { error = "Could not find the requested student" });

            return Ok(foundStudent);
        }

        [HttpGet("/students/view")]
        public IActionResult RenderStudentsPage()
        {
            return View("Index", Student.GetAll());
        }

        [HttpPost("/students")]
        public IActionResult CreateStudent([FromForm] string name, [FromForm] int? age, [FromForm] string major)
        {
            if (string.IsNullOrWhiteSpace(name) || age == null || string.IsNullOrWhiteSpace(major))
                return BadRequest(new { error = "Bad request. Payload was invalid" });

            Student.Create(new Student { Name = name, Age = age.Value, Major = major });
            return Redirect("/students/view");
        }

        [HttpPost("/students/update/{id}")]
        public IActionResult UpdateStudent(int id, [FromForm] Student data)
        {
            var updatedStudent = Student.Update(id, data);
            if (updatedStudent != null)
                return Redirect("/students/view");

            return NotFound(new { error = "Could not find student to update" });
        }

        [HttpPost("/students/delete/{id}")]
        public IActionResult DeleteStudent(int id)
        {
            var result = Student.Delete(id);
            if (result)
                return Redirect("/students/view");

            return NotFound(new { error = "Could not find student to delete" });
        }
    }
}
