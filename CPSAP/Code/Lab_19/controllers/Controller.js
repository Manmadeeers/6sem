const Student = require('../models/StudentsModel');

class StudentsController {
    getAllStudents(req, res) {
        res.status(200).json(Student.getAll());
    }

    getStudentById(req,res){
        const foundStudent = Student.getById(req.params.id);
        if(!foundStudent){
            res.status(404).json({error:"Could not find the requested student"});
        }
        else{
            res.status(200).json(foundStudent);
        }
    }

    renderStudentsPage(req, res) {
        res.render('index', { students: Student.getAll() });
    }

    createStudent(req, res) {
        const { name, age, major } = req.body;
        if (!name || !age || !major) {
            return res.status(400).json({ error: "Bad request. Payload was invalid" });

        }
        Student.create({ name, age, major });
        res.redirect('/students/view');
    }

    updateStudent(req, res) {
        const updatedStudent = Student.update(req.params.id, req.body);
        if (updatedStudent) {
            res.redirect('/students/view');
        }
        else {
            res.status(404).json({ error: "Could not find student to update" });
        }
    }

    deleteStudent(req, res) {
        const result = Student.delete(req.params.id);
        if (result) {
            res.redirect('/students/view');
        }
        else {
            res.status(404).json({ error: "Could not find student to delete" });
        }
    }
}


module.exports = StudentsController; 