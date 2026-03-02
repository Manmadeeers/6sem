const StudentModel = require('../models/studentsModel.js');

class StudentsController {
    renderIndexPage(req, res) {
        res.render('index', { students: StudentModel.getAllStudents() });
    }

    getAllStudents(req, res) {
        res.json(StudentModel.getAllStudents());
    }

    getStudentById(req, res) {
        const id = Number(req.params.id);
        const retrievedStudent = StudentModel.getStudentById(id);
        if (retrievedStudent) {
            res.json(retrievedStudent);
        } else {
            res.status(404).json({ error: `Not found. Could not find a student with id ${id}` });
        }
    }

    createStudent(req, res) {
        const name = req.body.name;
        const age = Number(req.body.age);     
        const major = req.body.major;

        if (!name || typeof name !== 'string' || Number.isNaN(age) || !major || typeof major !== 'string') {
            return res.status(400).json({ error: "Bad request. Payload or its fields are invalid" });
        }

        StudentModel.createStudent({ name, age, major });
        res.redirect('/students'); 
    }

    updateStudent(req, res) {
        const name = req.body.name;
        const age = Number(req.body.age);
        const major = req.body.major;

        if (!name || typeof name !== 'string' || Number.isNaN(age) || !major || typeof major !== 'string') {
            return res.status(400).json({ error: "Bad request. Payload or its fields are invalid" });
        }

        const id = Number(req.params.id);
        const updateResult = StudentModel.updateStudent(id, { name, age, major });
        if (updateResult) {
            res.redirect('/students');
        } else {
            res.status(404).json({ error: `Not found. Could not update a student with id ${id}` });
        }
    }

    deleteUser(req, res) {  
        const id = Number(req.params.id);
        const deletionResult = StudentModel.removeStudent(id);
        if (deletionResult) {
            res.redirect('/students');
        } else {
            res.status(404).json({ error: `Not found. Could not delete a student with id ${id}` });
        }
    }
}

module.exports = StudentsController;