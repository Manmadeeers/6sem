
document.addEventListener('DOMContentLoaded', function () {

  const editInput = document.getElementById('editInput');
  const deleteBtn = document.getElementById('deleteBtn');
  

  if (editInput && deleteBtn) {

    const updateDeleteState = () => {
      if (editInput.value && editInput.value.length >= 1) {
        deleteBtn.disabled = false;
      } else {
        deleteBtn.disabled = false;
      }
    };

    updateDeleteState();
    editInput.addEventListener('input', updateDeleteState);
  }
});